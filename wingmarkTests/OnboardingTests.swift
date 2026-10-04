import Foundation
import Testing
@testable import wingmark

@MainActor
@Suite(.serialized)
struct OnboardingTests {
    private func withLanguage(_ language: AppLanguage, _ body: () -> Void) {
        let previous = UserDefaults.standard.string(forKey: AppLanguage.storageKey)
        UserDefaults.standard.set(language.rawValue, forKey: AppLanguage.storageKey)
        body()
        UserDefaults.standard.set(previous, forKey: AppLanguage.storageKey)
    }

    @Test func pagesHaveDistinctSymbolsAndCopy() {
        let pages = OnboardingPage.allCases
        #expect(pages.count == 3)
        #expect(Set(pages.map(\.symbol)).count == pages.count)
        #expect(pages.allSatisfy { !$0.title.isEmpty && !$0.message.isEmpty })
    }

    @Test func pagesAreTranslatedToTurkish() {
        var english: [String] = []
        var turkish: [String] = []
        withLanguage(.english) { english = OnboardingPage.allCases.flatMap { [$0.title, $0.message] } }
        withLanguage(.turkish) { turkish = OnboardingPage.allCases.flatMap { [$0.title, $0.message] } }
        #expect(english.count == turkish.count)
        for (en, tr) in zip(english, turkish) {
            #expect(en != tr, "\(en) has no Turkish translation")
        }
    }

    @Test func pagesAvoidUnsupportedClaims() {
        let text = OnboardingPage.allCases.flatMap { [$0.title, $0.message] }.joined(separator: " ").lowercased()
        for claim in ["best", "#1", "guarantee", "100%", "any bird", "every species", "identif" + "ies"] {
            #expect(!text.contains(claim), "onboarding copy contains \"\(claim)\"")
        }
    }
}
