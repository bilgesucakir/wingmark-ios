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

    @Test func showsOnceForAnAccountCreatedRecently() {
        let walkthrough = walkthrough()
        let created = now.addingTimeInterval(-3600)
        #expect(walkthrough.shouldShow(userId: user, createdAt: created, now: now))
        walkthrough.markSeen(userId: user)
        #expect(!walkthrough.shouldShow(userId: user, createdAt: created, now: now))
    }

    @Test func skipsOldAccountsAndAccountsWithoutADate() {
        let walkthrough = walkthrough()
        #expect(!walkthrough.shouldShow(userId: user, createdAt: now.addingTimeInterval(-30 * 86_400), now: now))
        #expect(!walkthrough.shouldShow(userId: user, createdAt: nil, now: now))
    }

    @Test func eachAccountKeepsItsOwnFlag() {
        let walkthrough = walkthrough()
        let created = now.addingTimeInterval(-60)
        walkthrough.markSeen(userId: user)
        #expect(walkthrough.shouldShow(userId: UUID(), createdAt: created, now: now))
    }
}
