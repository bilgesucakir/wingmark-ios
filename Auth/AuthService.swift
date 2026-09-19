import Foundation

/// Mirrors wingmark-backend's UserProfileResponseDto.
struct AuthenticatedUser {
    let id: UUID
    let email: String
    let username: String
    let firstName: String
    let lastName: String
    let profilePicture: String?
    let role: Role
    let emailVerified: Bool
    let createdAt: Date

    var fullName: String { "\(firstName) \(lastName)" }
}

/// Mirrors wingmark-backend's Role enum. The ADMIN-only endpoints (species/badge
/// catalog management) are operated through the separate web-based admin panel,
/// not this app, so nothing here branches on role yet beyond carrying it along.
enum Role: String {
    case user = "USER"
    case admin = "ADMIN"
}

enum AuthError: LocalizedError {
    case missingFields
    case server(String)

    var errorDescription: String? {
        switch self {
        case .missingFields: "Please fill in all fields."
        case .server(let message): message
        }
    }
}

/// Result of a successful login/register call: the token pair plus the
/// resolved profile. `AuthSession` hangs onto the tokens for later
/// authenticated requests (bird logs, badges, etc.) once those are wired up.
struct AuthResult {
    let user: AuthenticatedUser
    let accessToken: String
    let refreshToken: String
}

/// Talks to the wingmark-backend `/api/auth` endpoints (register/login/refresh).
/// `BackendAuthService` is the real implementation, live at wingmark-backend.onrender.com;
/// `MockAuthService` remains for previews/offline work.
protocol AuthServicing {
    func login(email: String, password: String) async throws -> AuthResult
    func register(username: String, firstName: String, lastName: String, email: String, password: String) async throws -> AuthResult
}

/// Stand-in for the real backend. Accepts anything non-empty and "succeeds"
/// after a short delay. Kept around for SwiftUI previews and offline UI work.
struct MockAuthService: AuthServicing {
    func login(email: String, password: String) async throws -> AuthResult {
        guard !email.isEmpty, !password.isEmpty else { throw AuthError.missingFields }
        try await Task.sleep(nanoseconds: 400_000_000)
        let handle = email.components(separatedBy: "@").first ?? email
        let user = AuthenticatedUser(
            id: UUID(),
            email: email,
            username: handle,
            firstName: handle.capitalized,
            lastName: "",
            profilePicture: nil,
            role: .user,
            emailVerified: true,
            createdAt: .now
        )
        return AuthResult(user: user, accessToken: "mock-access-token", refreshToken: "mock-refresh-token")
    }

    func register(username: String, firstName: String, lastName: String, email: String, password: String) async throws -> AuthResult {
        guard !username.isEmpty, !email.isEmpty, !password.isEmpty else { throw AuthError.missingFields }
        try await Task.sleep(nanoseconds: 400_000_000)
        let user = AuthenticatedUser(
            id: UUID(),
            email: email,
            username: username,
            firstName: firstName,
            lastName: lastName,
            profilePicture: nil,
            role: .user,
            emailVerified: false,
            createdAt: .now
        )
        return AuthResult(user: user, accessToken: "mock-access-token", refreshToken: "mock-refresh-token")
    }
}
