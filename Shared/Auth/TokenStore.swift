import Foundation
import Security

struct TokenPair: Codable, Sendable, Equatable {
    let accessToken: String
    let refreshToken: String
    /// Legal documents whose current version the user hasn't accepted. Raw strings so an unknown type can't break login.
    var pendingConsents: [String]?

    var pendingConsentTypes: [ConsentType] { (pendingConsents ?? []).compactMap(ConsentType.init(rawValue:)) }
}

protocol TokenStore: AnyObject {
    func load() -> TokenPair?
    func save(_ tokens: TokenPair)
    func clear()
}

/// Reads and writes one Keychain item per access group. Tests pass their own, so no real Keychain is touched.
struct KeychainStorage {
    var read: (_ group: String) -> Data?
    var write: (_ data: Data, _ group: String) -> Bool
    var delete: (_ group: String) -> Void

    static func live(service: String = "com.bilgesucakir.wingmark.auth", account: String = "session") -> KeychainStorage {
        func query(_ group: String) -> [String: Any] {
            [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
                kSecAttrAccessGroup as String: group,
            ]
        }
        return KeychainStorage(
            read: { group in
                var request = query(group)
                request[kSecReturnData as String] = true
                request[kSecMatchLimit as String] = kSecMatchLimitOne
                var item: CFTypeRef?
                return SecItemCopyMatching(request as CFDictionary, &item) == errSecSuccess ? item as? Data : nil
            },
            write: { data, group in
                let attributes: [String: Any] = [
                    kSecValueData as String: data,
                    kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
                ]
                let status = SecItemUpdate(query(group) as CFDictionary, attributes as CFDictionary)
                if status == errSecItemNotFound {
                    return SecItemAdd(query(group).merging(attributes) { $1 } as CFDictionary, nil) == errSecSuccess
                }
                return status == errSecSuccess
            },
            delete: { group in SecItemDelete(query(group) as CFDictionary) }
        )
    }
}

/// The login lives in a Keychain group the Share Extension can read too. Older installs kept it in the app's own group, so
/// `migrateLegacyToken()` moves it once and `load()` still finds it until then. Never cached, because two processes use it
/// and the refresh token rotates: each must see the latest pair.
final class KeychainTokenStore: TokenStore {
    private let storage: KeychainStorage
    private let sharedGroup: String
    private let legacyGroup: String

    init(
        storage: KeychainStorage = .live(),
        sharedGroup: String = AppConfig.keychainAccessGroup,
        legacyGroup: String = AppConfig.legacyKeychainAccessGroup
    ) {
        self.storage = storage
        self.sharedGroup = sharedGroup
        self.legacyGroup = legacyGroup
    }

    func load() -> TokenPair? {
        decode(storage.read(sharedGroup)) ?? decode(storage.read(legacyGroup))
    }

    func save(_ tokens: TokenPair) {
        guard let data = try? JSONEncoder().encode(tokens) else { return }
        if storage.write(data, sharedGroup) {
            storage.delete(legacyGroup)
        } else if storage.write(data, legacyGroup) {
            // Shared group unavailable: keep the app signed in and never leave an older pair there to win in `load()`.
            storage.delete(sharedGroup)
        }
    }

    func clear() {
        storage.delete(sharedGroup)
        storage.delete(legacyGroup)
    }

    /// Moves a token from the app's own group to the shared one. The old item is deleted only after the new one reads back.
    func migrateLegacyToken() {
        guard let legacy = storage.read(legacyGroup) else { return }
        if storage.read(sharedGroup) == nil {
            guard storage.write(legacy, sharedGroup), storage.read(sharedGroup) == legacy else { return }
        }
        storage.delete(legacyGroup)
    }

    private func decode(_ data: Data?) -> TokenPair? {
        data.flatMap { try? JSONDecoder().decode(TokenPair.self, from: $0) }
    }
}

final class InMemoryTokenStore: TokenStore {
    private(set) var tokens: TokenPair?

    init(_ tokens: TokenPair? = nil) {
        self.tokens = tokens
    }

    func load() -> TokenPair? { tokens }
    func save(_ tokens: TokenPair) { self.tokens = tokens }
    func clear() { tokens = nil }
}
