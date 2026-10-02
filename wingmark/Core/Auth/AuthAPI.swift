import Foundation

enum AuthAPI {
    struct RegisterRequest: Encodable, Sendable {
        let email: String
        let password: String
        let username: String
        let firstName: String?
        let lastName: String?
        var acceptedTermsVersion: String?
        var acceptedPrivacyVersion: String?
    }

    static func login(email: String, password: String) -> Endpoint<TokenPair> {
        Endpoint(.post, "auth/login", json: ["email": email, "password": password], requiresAuth: false)
    }

    static func register(_ request: RegisterRequest) -> Endpoint<RegisterResponse> {
        Endpoint(.post, "auth/register", json: request, requiresAuth: false)
    }

    static func resendVerificationEmail(email: String) -> Endpoint<EmptyResponse> {
        Endpoint(.post, "auth/resend-verification-email", json: ["email": email], requiresAuth: false)
    }

    static func refresh(refreshToken: String) -> Endpoint<TokenPair> {
        Endpoint(.post, "auth/refresh", json: ["refreshToken": refreshToken], requiresAuth: false)
    }

    static func logout(refreshToken: String) -> Endpoint<EmptyResponse> {
        Endpoint(.post, "auth/logout", json: ["refreshToken": refreshToken], requiresAuth: false)
    }

    static func logoutAll() -> Endpoint<EmptyResponse> {
        Endpoint(.post, "auth/logout-all")
    }

    static func forgotPassword(email: String) -> Endpoint<EmptyResponse> {
        Endpoint(.post, "auth/forgot-password", json: ["email": email], requiresAuth: false)
    }

    static func resetPassword(email: String, code: String, newPassword: String) -> Endpoint<EmptyResponse> {
        Endpoint(
            .post, "auth/reset-password",
            json: ["email": email, "code": code, "newPassword": newPassword],
            requiresAuth: false
        )
    }

    static func user(id: UUID) -> Endpoint<UserProfile> {
        Endpoint(.get, "users/\(id.uuidString.lowercased())")
    }

    static func changePassword(userId: UUID, currentPassword: String, newPassword: String) -> Endpoint<TokenPair> {
        Endpoint(
            .post, "users/\(userId.uuidString.lowercased())/password",
            json: ["currentPassword": currentPassword, "newPassword": newPassword]
        )
    }

    static func deleteAccount(userId: UUID, password: String) -> Endpoint<EmptyResponse> {
        Endpoint(.delete, "users/\(userId.uuidString.lowercased())", json: ["password": password])
    }
    struct ProfileUpdate: Encodable, Sendable, Equatable {
        var firstName: String?
        var lastName: String?
        var profilePicture: String?
        var favoriteSpeciesId: UUID?

        init(_ profile: UserProfile) {
            firstName = profile.firstName
            lastName = profile.lastName
            profilePicture = profile.profilePicture
            favoriteSpeciesId = profile.favoriteSpeciesId
        }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(firstName, forKey: .firstName)
            try container.encode(lastName, forKey: .lastName)
            try container.encode(profilePicture, forKey: .profilePicture)
            try container.encode(favoriteSpeciesId, forKey: .favoriteSpeciesId)
        }

        private enum CodingKeys: String, CodingKey {
            case firstName, lastName, profilePicture, favoriteSpeciesId
        }
    }

    struct Avatar: Decodable, Sendable {
        let key: String
    }

    /// PUT replaces every field, so always send the full set.
    static func updateProfile(userId: UUID, _ update: ProfileUpdate) -> Endpoint<UserProfile> {
        Endpoint(.put, "users/\(userId.uuidString.lowercased())", json: update)
    }

    static func settings(userId: UUID) -> Endpoint<UserSettings> {
        Endpoint(.get, "users/\(userId.uuidString.lowercased())/settings")
    }

    static func updateSettings(userId: UUID, _ settings: UserSettings) -> Endpoint<UserSettings> {
        Endpoint(.put, "users/\(userId.uuidString.lowercased())/settings", json: settings)
    }

    static func avatars() -> Endpoint<[Avatar]> {
        Endpoint(.get, "avatars", requiresAuth: false)
    }
}
