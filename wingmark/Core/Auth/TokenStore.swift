import Foundation
import Security

struct TokenPair: Codable, Sendable, Equatable {
    let accessToken: String
    let refreshToken: String
}

protocol TokenStore: AnyObject {
    func load() -> TokenPair?
    func save(_ tokens: TokenPair)
    func clear()
}

final class KeychainTokenStore: TokenStore {
    private let service: String
    private let account: String
    private var cached: TokenPair??

    init(service: String = "com.bilgesucakir.wingmark.auth", account: String = "session") {
        self.service = service
        self.account = account
    }

    func load() -> TokenPair? {
        if let cached { return cached }
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        let tokens = (status == errSecSuccess ? item as? Data : nil)
            .flatMap { try? JSONDecoder().decode(TokenPair.self, from: $0) }
        cached = .some(tokens)
        return tokens
    }

    func save(_ tokens: TokenPair) {
        cached = .some(tokens)
        guard let data = try? JSONEncoder().encode(tokens) else { return }
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let status = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            SecItemAdd(baseQuery.merging(attributes) { $1 } as CFDictionary, nil)
        }
    }

    func clear() {
        cached = .some(nil)
        SecItemDelete(baseQuery as CFDictionary)
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
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
