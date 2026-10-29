import Foundation
import Testing
@testable import wingmark

struct TokenStoreTests {
    private final class FakeKeychain {
        var items: [String: Data] = [:]
        var failingWrites: Set<String> = []

        var storage: KeychainStorage {
            KeychainStorage(
                read: { self.items[$0] },
                write: { data, group in
                    guard !self.failingWrites.contains(group) else { return false }
                    self.items[group] = data
                    return true
                },
                delete: { self.items[$0] = nil }
            )
        }
    }

    private let shared = "TEAM.shared"
    private let legacy = "TEAM.app"

    private func store(_ keychain: FakeKeychain) -> KeychainTokenStore {
        KeychainTokenStore(storage: keychain.storage, sharedGroup: shared, legacyGroup: legacy)
    }

    private func data(_ name: String) -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try! encoder.encode(TokenPair(accessToken: "access-\(name)", refreshToken: "refresh-\(name)"))
    }

    @Test func movesTheOldTokenToTheSharedGroupAndKeepsTheUserSignedIn() {
        let keychain = FakeKeychain()
        keychain.items[legacy] = data("old")
        let store = store(keychain)
        store.migrateLegacyToken()
        #expect(keychain.items[shared] == data("old"))
        #expect(keychain.items[legacy] == nil)
        #expect(store.load()?.accessToken == "access-old")
    }

    @Test func findsTheOldTokenBeforeTheMoveHappens() {
        let keychain = FakeKeychain()
        keychain.items[legacy] = data("old")
        #expect(store(keychain).load()?.refreshToken == "refresh-old")
    }

    @Test func doesNothingWhenThereIsNoOldToken() {
        let keychain = FakeKeychain()
        store(keychain).migrateLegacyToken()
        #expect(keychain.items.isEmpty)
        #expect(store(keychain).load() == nil)
    }

    @Test func keepsTheSharedTokenAndDropsTheOldOneWhenBothExist() {
        let keychain = FakeKeychain()
        keychain.items[legacy] = data("old")
        keychain.items[shared] = data("new")
        let store = store(keychain)
        store.migrateLegacyToken()
        #expect(keychain.items[legacy] == nil)
        #expect(store.load()?.accessToken == "access-new")
    }

    @Test func keepsTheOldTokenWhenTheSharedWriteFails() {
        let keychain = FakeKeychain()
        keychain.items[legacy] = data("old")
        keychain.failingWrites = [shared]
        let store = store(keychain)
        store.migrateLegacyToken()
        #expect(keychain.items[legacy] == data("old"))
        #expect(keychain.items[shared] == nil)
        #expect(store.load()?.accessToken == "access-old")
    }

    @Test func movingTwiceIsHarmless() {
        let keychain = FakeKeychain()
        keychain.items[legacy] = data("old")
        let store = store(keychain)
        store.migrateLegacyToken()
        store.migrateLegacyToken()
        #expect(store.load()?.accessToken == "access-old")
    }

    @Test func savesToTheSharedGroupAndClearsTheOldOne() {
        let keychain = FakeKeychain()
        keychain.items[legacy] = data("old")
        let store = store(keychain)
        store.save(TokenPair(accessToken: "access-new", refreshToken: "refresh-new"))
        #expect(keychain.items[legacy] == nil)
        #expect(store.load()?.refreshToken == "refresh-new")
    }

    @Test func fallsBackToTheOldGroupWhenTheSharedOneCantBeWritten() {
        let keychain = FakeKeychain()
        keychain.items[shared] = data("stale")
        keychain.failingWrites = [shared]
        let store = store(keychain)
        store.save(TokenPair(accessToken: "access-new", refreshToken: "refresh-new"))
        #expect(store.load()?.accessToken == "access-new")
    }

    @Test func clearRemovesBothCopies() {
        let keychain = FakeKeychain()
        keychain.items[legacy] = data("old")
        keychain.items[shared] = data("new")
        let store = store(keychain)
        store.clear()
        #expect(store.load() == nil)
    }

    @Test func alwaysReadsTheLatestTokenInsteadOfACopy() {
        let keychain = FakeKeychain()
        let store = store(keychain)
        keychain.items[shared] = data("one")
        #expect(store.load()?.accessToken == "access-one")
        keychain.items[shared] = data("two")
        #expect(store.load()?.accessToken == "access-two")
    }
}
