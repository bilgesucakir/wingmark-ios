import Foundation

/// The login the app saved in the shared Keychain group. The Share Extension may refresh it, but a rejected refresh must never
/// clear it, or sharing a photo could sign the person out of the app.
final class SharedLoginStore: TokenStore {
    private let base = KeychainTokenStore()

    func load() -> TokenPair? { base.load() }
    func save(_ tokens: TokenPair) { base.save(tokens) }
    func clear() {}
}
