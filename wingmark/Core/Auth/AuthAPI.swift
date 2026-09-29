import Foundation

enum AuthAPI {
    struct RegisterRequest: Encodable, Sendable {
        let email: String
        let password: String
        let username: String
        let firstName: String?
        let lastName: String?
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
}
