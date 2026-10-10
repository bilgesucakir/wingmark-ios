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
    /// Legal documents the user must accept before using the app.
    private(set) var pendingConsents: [ConsentType] = []
    var sessionExpiredNotice = false
    var accountDeletedNotice = false

    let client: APIClient
    private let wipeLocalData: () -> Void

    init(client: APIClient, wipeLocalData: @escaping () -> Void = { LocalData.wipe() }) {
        self.client = client
        self.wipeLocalData = wipeLocalData
        client.onSessionExpired = { [weak self] in self?.handleSessionExpired() }
        client.onTokensRefreshed = { [weak self] tokens in self?.pendingConsents = tokens.pendingConsentTypes }
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

    /// Tells the server the walkthrough was closed, so no other device shows it again. Safe to repeat.
    func markWalkthroughSeen() async {
        guard let userId else { return }
        if (try? await client.send(AuthAPI.walkthroughSeen(userId: userId))) != nil {
            profile?.walkthroughSeenAt = profile?.walkthroughSeenAt ?? .now
        }
    }

    func loadSettings() async {
        guard let userId else { return }
        if let settings = try? await client.send(AuthAPI.settings(userId: userId)) {
            self.settings = settings
        }
    }

    // MARK: - Profile & settings

    func updateProfile(_ update: AuthAPI.ProfileUpdate) async throws(APIError) {
        guard let userId else { throw .sessionExpired }
        profile = try await client.send(AuthAPI.updateProfile(userId: userId, update))
    }

    /// The backend requires both fields, so the stored unit preference is sent back unchanged.
    func updateSettings(locale: String) async throws(APIError) {
        guard let userId else { throw .sessionExpired }
        let updated = UserSettings(unitPreference: settings?.unitPreference ?? .device, locale: locale)
        settings = try await client.send(AuthAPI.updateSettings(userId: userId, updated))
    }

    // MARK: - Sign in / up

    func logIn(email: String, password: String) async throws(APIError) {
        do throws(APIError) {
            let tokens = try await client.send(AuthAPI.login(email: email, password: password))
            // Known before the signed-in UI appears, so nothing there can show over the terms screen.
            pendingConsents = tokens.pendingConsentTypes
            try adopt(tokens)
        } catch {
            pendingConsents = []
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
        pendingConsents = tokens.pendingConsentTypes
    }

    // MARK: - Legal & data

    func legalDocuments() async throws(APIError) -> LegalDocuments {
        try await client.send(LegalAPI.documents())
    }

    /// Accepts the current version of each pending document. A version that changed meanwhile surfaces as
    /// `CONSENT_VERSION_MISMATCH`, so callers refetch the documents and ask again.
    func acceptPendingConsents(_ documents: LegalDocuments) async throws(APIError) {
        guard let userId else { throw .sessionExpired }
        for type in pendingConsents {
            guard let version = documents.version(of: type) else { continue }
            let result = try await client.send(LegalAPI.accept(type, version: version, userId: userId))
            pendingConsents = result.pendingTypes
        }
    }

    /// Downloads the account's data export to a temporary JSON file for sharing.
    func exportData() async throws(APIError) -> URL {
        guard let userId else { throw .sessionExpired }
        let export = try await client.send(LegalAPI.export(userId: userId))
        let file = URL.temporaryDirectory.appending(path: "wingmark-data-export.json")
        do {
            try export.data.write(to: file, options: [.atomic, .completeFileProtection])
        } catch {
            throw .decoding("Couldn't save the export")
        }
        return file
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
        wipeLocalData()
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
        pendingConsents = []
        ImageLoader.shared.clear()
        state = .signedOut
    }

    private func handleSessionExpired() {
        guard userId != nil else { return }
        profile = nil
        settings = nil
        pendingConsents = []
        sessionExpiredNotice = true
        state = .signedOut
    }
}
