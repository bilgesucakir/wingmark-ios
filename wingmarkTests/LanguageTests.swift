import CoreLocation
import Foundation
import Testing
@testable import wingmark

@MainActor
@Suite(.serialized)
struct LanguageTests {
    private func withLanguage(_ language: AppLanguage, _ body: () -> Void) {
        let previous = UserDefaults.standard.string(forKey: AppLanguage.storageKey)
        UserDefaults.standard.set(language.rawValue, forKey: AppLanguage.storageKey)
        body()
        UserDefaults.standard.set(previous, forKey: AppLanguage.storageKey)
    }

    @Test func turkishOverrideTranslatesCodeBuiltStrings() {
        withLanguage(.turkish) {
            #expect(LifeStage.adult.title == "Yetişkin")
            #expect(Gender.male.title == "Erkek")
            #expect(Locale.app.identifier == "tr")
        }
        withLanguage(.english) {
            #expect(LifeStage.adult.title == "Adult")
        }
    }

    @Test func defaultsToTurkishOnlyOnTurkishDevices() {
        #expect(AppLanguage.deviceDefault(preferredLanguages: ["tr-TR"]) == .turkish)
        #expect(AppLanguage.deviceDefault(preferredLanguages: ["en-GB", "tr-TR"]) == .english)
        #expect(AppLanguage.deviceDefault(preferredLanguages: ["de-DE"]) == .english)
        #expect(AppLanguage.deviceDefault(preferredLanguages: []) == .english)
    }

    @Test func legacySystemChoiceFallsBackToDeviceDefault() {
        let previous = UserDefaults.standard.string(forKey: AppLanguage.storageKey)
        UserDefaults.standard.set("system", forKey: AppLanguage.storageKey)
        #expect(AppLanguage.current == AppLanguage.deviceDefault())
        UserDefaults.standard.set(previous, forKey: AppLanguage.storageKey)
    }

    @Test func formFollowsSeenNowAndPhotoDate() async throws {
        let model = SightingFormModel(editing: nil)
        #expect(model.seenNow)
        model.coordinate = .init(latitude: 41, longitude: 29)
        #expect(model.makeInput()?.observedAt.map { abs($0.timeIntervalSinceNow) < 5 } == true)

        model.seenNow = false
        model.observedAt = try #require(JSONCoding.parseDate("2026-09-01T10:00:00Z"))
        #expect(model.makeInput()?.observedAt == JSONCoding.parseDate("2026-09-01T10:00:00Z"))
    }
}
