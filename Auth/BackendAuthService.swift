import Foundation

/// Real implementation of `AuthServicing` against the deployed
/// wingmark-backend (https://wingmark-backend.onrender.com).
///
/// `/api/auth/login` and `/register` only return a token pair (no profile
/// data), so this decodes the access token's JWT `sub` claim to get the
/// user's id, then fetches the full profile via `GET /api/users/{id}`.
struct BackendAuthService: AuthServicing {
    private let baseURL = URL(string: "https://wingmark-backend.onrender.com")!
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        // Render's free tier cold-starts a sleeping instance, which can take
        // well over the 60s default timeout on the first request.
        config.timeoutIntervalForRequest = 90
        session = URLSession(configuration: config)
    }

    func login(email: String, password: String) async throws -> AuthResult {
        let tokens: TokenResponse = try await post(
            "/api/auth/login",
            body: ["email": email, "password": password]
        )
        return try await result(from: tokens)
    }

    func register(username: String, firstName: String, lastName: String, email: String, password: String) async throws -> AuthResult {
        var body = ["email": email, "password": password, "username": username]
        if !firstName.isEmpty { body["firstName"] = firstName }
        if !lastName.isEmpty { body["lastName"] = lastName }
        let tokens: TokenResponse = try await post("/api/auth/register", body: body)
        return try await result(from: tokens)
    }

    private func result(from tokens: TokenResponse) async throws -> AuthResult {
        guard let userId = Self.userId(fromJWT: tokens.accessToken) else {
            throw AuthError.server("Couldn't read the server's response. Please try again.")
        }
        var request = URLRequest(url: baseURL.appendingPathComponent("/api/users/\(userId)"))
        request.setValue("Bearer \(tokens.accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        try Self.checkStatus(response, data: data)
        let profile = try Self.decoder.decode(UserProfileDto.self, from: data)
        return AuthResult(user: profile.asAuthenticatedUser, accessToken: tokens.accessToken, refreshToken: tokens.refreshToken)
    }

    private func post<T: Decodable>(_ path: String, body: [String: String]) async throws -> T {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await session.data(for: request)
        try Self.checkStatus(response, data: data)
        return try Self.decoder.decode(T.self, from: data)
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallback = ISO8601DateFormatter()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = formatter.date(from: string) ?? fallback.date(from: string) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unrecognized date: \(string)")
        }
        return decoder
    }

    private static func checkStatus(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) else { return }
        if let backendError = try? JSONDecoder().decode(BackendErrorResponse.self, from: data) {
            throw AuthError.server(backendError.userMessage)
        }
        throw AuthError.server("Request failed with status \(http.statusCode). Please try again.")
    }

    /// Decodes the unverified JWT payload to read the `sub` claim. Signature
    /// verification is the backend's job; the client only needs the user id.
    private static func userId(fromJWT token: String) -> String? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var base64 = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64 += "=" }
        guard let data = Data(base64Encoded: base64),
              let claims = try? JSONDecoder().decode(JWTClaims.self, from: data) else { return nil }
        return claims.sub
    }
}

private struct JWTClaims: Decodable {
    let sub: String
}

private struct TokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let expiresInMs: Int
}

private struct UserProfileDto: Decodable {
    let id: UUID
    let email: String
    let username: String
    let firstName: String?
    let lastName: String?
    let profilePicture: String?
    let role: String
    let emailVerified: Bool
    let createdAt: Date

    var asAuthenticatedUser: AuthenticatedUser {
        AuthenticatedUser(
            id: id,
            email: email,
            username: username,
            firstName: firstName ?? "",
            lastName: lastName ?? "",
            profilePicture: profilePicture,
            role: Role(rawValue: role) ?? .user,
            emailVerified: emailVerified,
            createdAt: createdAt
        )
    }
}

/// Spring's default validation-error body: {"message", "validationErrors": {field: reason}}.
private struct BackendErrorResponse: Decodable {
    let message: String?
    let validationErrors: [String: String]?

    var userMessage: String {
        if let validationErrors, !validationErrors.isEmpty {
            return validationErrors.values.joined(separator: "\n")
        }
        return message ?? "Something went wrong. Please try again."
    }
}
