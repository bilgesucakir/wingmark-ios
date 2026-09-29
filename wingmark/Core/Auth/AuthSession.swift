import Foundation
import Observation

@Observable
final class AuthSession {
    enum State: Equatable {
        case launching
        case signedOut
        case needsVerification(email: String)
        case signedIn(userId: UUID)
    }

    private(set) var state: State = .launching
    private(set) var profile: UserProfile?
    private(set) var settings: UserSettings?
    var sessionExpiredNotice = false
    var accountDeletedNotice = false

    let client: APIClient

    init(client: APIClient) {
        self.client = client
        client.onSessionExpired = { [weak self] in self?.handleSessionExpired() }
    }

    var userId: UUID? {
        if case .signedIn(let id) = state { return id }
        return nil
    }

    func restore() async {
        guard state == .launching else { return }
        guard let tokens = client.tokenStore.load(), let id = JWT.subject(of: tokens.accessToken) else {
            client.tokenStore.clear()
            state = .signedOut
            return
        }
        state = .signedIn(userId: id)
        await refreshProfile()
        await loadSettings()
    }

    func refreshProfile() async {
        guard let userId else { return }
        if let profile = try? await client.send(AuthAPI.user(id: userId)) {
            self.profile = profile
        }
    }

    func loadSettings() async {
        guard let userId else { return }
        if let settings = try? await client.send(AuthAPI.settings(userId: userId)) {
            self.settings = settings
            UnitPreference.current = settings.unitPreference
        }
    }

    // MARK: - Profile & settings

    func updateProfile(_ update: AuthAPI.ProfileUpdate) async throws(APIError) {
        guard let userId else { throw .sessionExpired }
        profile = try await client.send(AuthAPI.updateProfile(userId: userId, update))
    }

    func updateSettings(unitPreference: UnitPreference? = nil, locale: String? = nil) async throws(APIError) {
        guard let userId else { throw .sessionExpired }
        let current = settings ?? UserSettings(unitPreference: UnitPreference.current, locale: AppLanguage.current.resolvedCode)
        let updated = UserSettings(
            unitPreference: unitPreference ?? current.unitPreference,
            locale: locale ?? current.locale
        )
        settings = try await client.send(AuthAPI.updateSettings(userId: userId, updated))
        UnitPreference.current = settings?.unitPreference ?? updated.unitPreference
    }

    // MARK: - Sign in / up

    func logIn(email: String, password: String) async throws(APIError) {
        do throws(APIError) {
            let tokens = try await client.send(AuthAPI.login(email: email, password: password))
            try adopt(tokens)
        } catch {
            guard error.code == .emailNotVerified else { throw error }
            state = .needsVerification(email: email)
            return
        }
        sessionExpiredNotice = false
        accountDeletedNotice = false
        await refreshProfile()
        await loadSettings()
    }

    func register(_ request: AuthAPI.RegisterRequest) async throws(APIError) {
        let response = try await client.send(AuthAPI.register(request))
        state = .needsVerification(email: response.email)
    }

    func resendVerificationEmail(to email: String) async throws(APIError) {
        _ = try await client.send(AuthAPI.resendVerificationEmail(email: email))
    }

    func showLogin() {
        state = .signedOut
    }

    // MARK: - Passwords

    func requestPasswordReset(email: String) async throws(APIError) {
        _ = try await client.send(AuthAPI.forgotPassword(email: email))
    }

    func resetPassword(email: String, code: String, newPassword: String) async throws(APIError) {
        _ = try await client.send(AuthAPI.resetPassword(email: email, code: code, newPassword: newPassword))
        signOutLocally()
    }

    func changePassword(current: String, new: String) async throws(APIError) {
        guard let userId else { throw .sessionExpired }
        let tokens = try await client.send(
            AuthAPI.changePassword(userId: userId, currentPassword: current, newPassword: new)
        )
        client.tokenStore.save(tokens)
    }

    // MARK: - Sign out

    func logOut() async {
        let refreshToken = client.tokenStore.load()?.refreshToken
        signOutLocally()
        if let refreshToken {
            _ = try? await client.send(AuthAPI.logout(refreshToken: refreshToken))
        }
    }

    func logOutAllDevices() async throws(APIError) {
        _ = try await client.send(AuthAPI.logoutAll())
        signOutLocally()
    }

    func deleteAccount(password: String) async throws(APIError) {
        guard let userId else { throw .sessionExpired }
        _ = try await client.send(AuthAPI.deleteAccount(userId: userId, password: password))
        signOutLocally()
        accountDeletedNotice = true
    }

    // MARK: - Private

    private func adopt(_ tokens: TokenPair) throws(APIError) {
        guard let id = JWT.subject(of: tokens.accessToken) else {
            throw .decoding("Access token has no user id")
        }
        client.tokenStore.save(tokens)
        state = .signedIn(userId: id)
    }

    private func signOutLocally() {
        client.tokenStore.clear()
        profile = nil
        settings = nil
        ImageLoader.shared.clear()
        state = .signedOut
    }

    private func handleSessionExpired() {
        guard userId != nil else { return }
        profile = nil
        settings = nil
        sessionExpiredNotice = true
        state = .signedOut
    }
}
