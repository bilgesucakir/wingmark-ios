import Foundation
import Testing
@testable import wingmark

struct ReviewPromptTests {
    private func defaults(launches: Int = 2) -> UserDefaults {
        let defaults = UserDefaults(suiteName: "ReviewPromptTests.\(UUID().uuidString)")!
        for _ in 0..<launches { ReviewPrompt.recordLaunch(defaults: defaults) }
        return defaults
    }

    @Test func asksWhenTheTenthSightingIsSaved() {
        #expect(ReviewPrompt.shouldAsk(totalSightings: 10, isNewSighting: true, defaults: defaults()))
    }

    @Test func doesNotAskBeforeTheMilestone() {
        #expect(!ReviewPrompt.shouldAsk(totalSightings: 9, isNewSighting: true, defaults: defaults()))
    }

    @Test func doesNotAskInTheFirstSession() {
        #expect(!ReviewPrompt.shouldAsk(totalSightings: 10, isNewSighting: true, defaults: defaults(launches: 1)))
    }

    @Test func doesNotAskAfterAnEdit() {
        #expect(!ReviewPrompt.shouldAsk(totalSightings: 10, isNewSighting: false, defaults: defaults()))
    }

    @Test func doesNotAskTwiceForTheSameMilestone() {
        let defaults = defaults()
        #expect(ReviewPrompt.shouldAsk(totalSightings: 10, isNewSighting: true, defaults: defaults))
        #expect(!ReviewPrompt.shouldAsk(totalSightings: 10, isNewSighting: true, defaults: defaults))
        #expect(!ReviewPrompt.shouldAsk(totalSightings: 11, isNewSighting: true, defaults: defaults))
    }

    @Test func doesNotAskAgainLater() {
        let defaults = defaults()
        #expect(ReviewPrompt.shouldAsk(totalSightings: 10, isNewSighting: true, defaults: defaults))
        #expect(!ReviewPrompt.shouldAsk(totalSightings: 50, isNewSighting: true, defaults: defaults))
    }

    @Test func aLongTimeUserIsAskedOnlyOnce() {
        let defaults = defaults()
        #expect(ReviewPrompt.shouldAsk(totalSightings: 60, isNewSighting: true, defaults: defaults))
        #expect(!ReviewPrompt.shouldAsk(totalSightings: 61, isNewSighting: true, defaults: defaults))
    }
}
