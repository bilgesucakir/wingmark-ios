import Foundation
import Testing
@testable import wingmark

@MainActor
struct AppWalkthroughTests {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)
    private let user = UUID()

    private func walkthrough() -> AppWalkthrough {
        AppWalkthrough(defaults: UserDefaults(suiteName: "AppWalkthroughTests-\(UUID().uuidString)")!)
    }

    @Test func showsUntilTheServerOrThisDeviceHasSeenIt() {
        let walkthrough = walkthrough()
        #expect(walkthrough.shouldShow(userId: user, seenOnServer: false))
        #expect(!walkthrough.shouldShow(userId: user, seenOnServer: true))
        walkthrough.markSeen(userId: user)
        #expect(!walkthrough.shouldShow(userId: user, seenOnServer: false))
        #expect(walkthrough.hasSeenLocally(userId: user))
    }

    @Test func eachAccountKeepsItsOwnFlag() {
        let walkthrough = walkthrough()
        walkthrough.markSeen(userId: user)
        #expect(walkthrough.shouldShow(userId: UUID(), seenOnServer: false))
    }

    @Test func theProfileDecodesTheServerFlag() throws {
        func profile(_ extra: String) throws -> UserProfile {
            let json = #"{"id":"3f2504e0-4f89-11d3-9a0c-0305e82c3301","email":"a@b.co","username":"ab","role":"USER","emailVerified":true\#(extra)}"#
            return try JSONCoding.makeDecoder().decode(UserProfile.self, from: Data(json.utf8))
        }
        #expect(try profile("").walkthroughSeenAt == nil)
        #expect(try profile(#","walkthroughSeenAt":null"#).walkthroughSeenAt == nil)
        #expect(try profile(#","walkthroughSeenAt":"2026-10-11T09:00:00Z""#).walkthroughSeenAt != nil)
    }
}
