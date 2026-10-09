import Foundation
import Testing
import UIKit
@testable import wingmark

@MainActor
struct WidgetTests {
    private func makeStore() -> SharedStore {
        let directory = FileManager.default.temporaryDirectory.appending(path: "widget-tests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return SharedStore(directory: directory)
    }

    private func log(_ id: Int, at observedAt: String, photo: Bool = false) throws -> BirdLog {
        let uuid = String(format: "00000000-0000-0000-0000-%012d", id)
        var json = DiaryFixtures.logJSON(id: uuid, observedAt: observedAt)
        if !photo { json = json.replacingOccurrences(of: #""photoUrl":"/uploads/a.jpg""#, with: #""photoUrl":null"#) }
        return try JSONCoding.makeDecoder().decode(BirdLog.self, from: Data(json.utf8))
    }

    private func badge(_ id: Int, progress: Int, target: Int, earned: Bool = false) -> BadgeProgress {
        BadgeProgress(id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", id))!, name: "Badge \(id)",
                      description: nil, icon: nil, tier: .bronze, earned: earned, earnedAt: nil, progress: progress, target: target)
    }

    @Test func nextBadgeIsTheUnearnedOneClosestToDone() {
        let summary = WidgetSync.summary(
            logs: [], badges: [badge(1, progress: 10, target: 10, earned: true), badge(2, progress: 2, target: 10),
                               badge(3, progress: 9, target: 10), badge(4, progress: 0, target: 0)],
            language: "en"
        )
        #expect(summary.nextBadge?.name == "Badge 3")
        #expect(summary.nextBadge?.fraction == 0.9)
        #expect(!summary.allBadgesEarned)
    }

    @Test func noNextBadgeWhenEverythingIsEarned() {
        let summary = WidgetSync.summary(logs: [], badges: [badge(1, progress: 5, target: 5, earned: true)], language: "tr")
        #expect(summary.nextBadge == nil && summary.allBadgesEarned && summary.language == "tr")
        #expect(!WidgetSync.summary(logs: [], badges: [], language: "en").allBadgesEarned)
    }

    @Test func latestSightingIsTheMostRecentAndCarriesNoLocation() throws {
        let older = try log(1, at: "2026-09-01T08:00:00Z")
        let newer = try log(2, at: "2026-09-29T07:30:00Z")
        let summary = WidgetSync.summary(logs: [older, newer], badges: [], language: "en")
        #expect(summary.latest?.id == newer.id)
        let json = try String(decoding: JSONEncoder().encode(summary), as: UTF8.self).lowercased()
        #expect(!json.contains("latitude") && !json.contains("longitude") && !json.contains("location"))
    }

    @Test func latestSightingCarriesGenderLifeStageAndNoteOnlyWhenKnown() throws {
        let known = try JSONCoding.makeDecoder().decode(BirdLog.self, from: Data(
            DiaryFixtures.logJSON(id: "00000000-0000-0000-0000-000000000001", observedAt: "2026-09-29T07:30:00Z", gender: "FEMALE")
                .replacingOccurrences(of: #""lifeStage":"ADULT""#, with: #""lifeStage":"BABY""#)
                .replacingOccurrences(of: #""note":null"#, with: #""note":"  Near the pond.  ""#).utf8))
        let latest = try #require(WidgetSync.summary(logs: [known], badges: [], language: "en").latest)
        #expect(latest.gender == Gender.female.title && latest.lifeStage == LifeStage.baby.title)
        #expect(latest.note == "Near the pond.")
        #expect(latest.traits(language: "en") == "\(Gender.female.title) · \(LifeStage.baby.title)")
        #expect(latest.traits(language: "tr") == "Dişi · Yavru")

        let unknown = try JSONCoding.makeDecoder().decode(BirdLog.self, from: Data(
            DiaryFixtures.logJSON(id: "00000000-0000-0000-0000-000000000002", observedAt: "2026-09-30T07:30:00Z")
                .replacingOccurrences(of: #""lifeStage":"ADULT""#, with: #""lifeStage":"UNKNOWN""#).utf8))
        let bare = try #require(WidgetSync.summary(logs: [unknown], badges: [], language: "en").latest)
        #expect(bare.gender == nil && bare.lifeStage == nil && bare.traits(language: "en") == nil)
    }

    @Test func aLongNoteIsCutAtAWordAndAnEmptyOneIsDropped() {
        let long = String(repeating: "feathers ", count: 40)
        let cut = WidgetSync.shortNote(long)
        #expect(cut?.hasSuffix("…") == true && (cut?.count ?? 999) <= 141)
        #expect(cut?.contains("feathers…") == true)
        #expect(WidgetSync.shortNote("   \n ") == nil && WidgetSync.shortNote(nil) == nil)
        #expect(WidgetSync.shortNote("Short") == "Short")
    }

    @Test func updateWritesOnceAndReloadsOnlyWhenSomethingChanged() async throws {
        let store = makeStore()
        var reloads = 0
        let logs = [try log(1, at: "2026-09-29T07:30:00Z")]
        for _ in 0..<2 {
            await WidgetSync.update(logs: logs, badges: [badge(1, progress: 1, target: 5)], language: "en",
                                    store: store, reload: { reloads += 1 }, loadImage: { _ in nil })
        }
        #expect(reloads == 1)
        #expect(store.read()?.latest?.id == logs[0].id)
    }

    @Test func updateSavesADownscaledPhotoOfTheLatestSighting() async throws {
        let store = makeStore()
        let big = UIGraphicsImageRenderer(size: CGSize(width: 2000, height: 1000)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2000, height: 1000))
        }
        await WidgetSync.update(logs: [try log(1, at: "2026-09-29T07:30:00Z", photo: true)], badges: [], language: "en",
                                store: store, reload: {}, loadImage: { _ in big })
        let saved = try #require(store.photoURL.flatMap { try? Data(contentsOf: $0) }.flatMap { UIImage(data: $0) })
        #expect(max(saved.size.width * saved.scale, saved.size.height * saved.scale) <= 600)
    }

    @Test func clearRemovesEverythingAboutThePerson() async throws {
        let store = makeStore()
        await WidgetSync.update(logs: [try log(1, at: "2026-09-29T07:30:00Z", photo: true)], badges: [badge(1, progress: 1, target: 5)],
                                language: "en", store: store, reload: {}, loadImage: { _ in UIImage(systemName: "bird") })
        #expect(store.read() != nil)
        var reloads = 0
        WidgetSync.clear(store: store, reload: { reloads += 1 })
        #expect(store.read() == nil)
        #expect(store.photoURL.map { !FileManager.default.fileExists(atPath: $0.path) } == true)
        #expect(reloads == 1)
    }

    @Test func languageIsSavedEvenWithoutASummary() {
        let store = makeStore()
        #expect(store.readLanguage() == nil)
        store.writeLanguage("tr")
        #expect(store.readLanguage() == "tr")
    }

    @Test func everyWidgetTextHasATurkishTranslation() {
        for key in WidgetText.Key.allCases {
            #expect(WidgetText.string(key, language: "en") != WidgetText.string(key, language: "tr"))
        }
        #expect(WidgetText.string(.logIn, language: nil) == "Log in to Wingmark")
    }
}

struct WidgetLanguageTests {
    @Test func badgeNameFollowsTheAppLanguage() {
        let badge = WidgetSummary.Badge(id: nil, name: "Gathering Finder", names: ["en": "Gathering Finder", "tr": "Buluşma Bulucu"], icon: nil, progress: 1, target: 2)
        #expect(badge.displayName(language: "tr") == "Buluşma Bulucu")
        #expect(badge.displayName(language: "en") == "Gathering Finder")
        #expect(badge.displayName(language: "de") == "Gathering Finder")
        #expect(WidgetSummary.Badge(id: nil, name: "Old", icon: nil, progress: 0, target: 1).displayName(language: "tr") == "Old")
    }
}

struct ObservedTimeTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ day: Int, _ hour: Int, _ minute: Int, month: Int = 10, year: Int = 2026) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    @Test func showsTheActualTimeWithTodayAndYesterdayInTheAppLanguage() {
        let now = date(9, 18, 0)
        let today = WidgetText.observed(date(9, 14, 30), now: now, language: "tr", calendar: calendar)
        #expect(today.contains("Bugün") && today.contains("14:30"))
        let yesterday = WidgetText.observed(date(8, 23, 5), now: now, language: "tr", calendar: calendar)
        #expect(yesterday.contains("Dün") && yesterday.contains("23:05"))
        let english = WidgetText.observed(date(9, 14, 30), now: now, language: "en", calendar: calendar)
        #expect(english.contains("Today") && english.contains("2:30"))
        #expect(WidgetText.observed(date(8, 9, 5), now: now, language: "en", calendar: calendar).contains("Yesterday"))
    }

    @Test func olderSightingsShowTheDate() {
        let now = date(9, 18, 0)
        let older = WidgetText.observed(date(3, 14, 30), now: now, language: "tr", calendar: calendar)
        #expect(older.contains("3") && older.contains("Eki") && older.contains("14:30"))
        #expect(!older.contains("2026"))
        let lastYear = WidgetText.observed(date(3, 14, 30, year: 2025), now: now, language: "en", calendar: calendar)
        #expect(lastYear.contains("2025"))
    }
}

struct RemoteURLTests {
    @Test func keepsEncodedCharactersAndEncodesAccentedOnes() {
        let url = RemoteURL.make("https://thumb.wikimedia.org/a/Tennōji_Park%2C_2015.jpg?utm_source=commons")
        #expect(url?.absoluteString == "https://thumb.wikimedia.org/a/Tenn%C5%8Dji_Park%2C_2015.jpg?utm_source=commons")
    }

    @Test func resolvesBackendPaths() {
        let base = URL(string: "https://example.com")!
        #expect(RemoteURL.make("/uploads/a.jpg", relativeTo: base)?.absoluteString == "https://example.com/uploads/a.jpg")
        #expect(RemoteURL.make("https://other.org/b.jpg", relativeTo: base)?.absoluteString == "https://other.org/b.jpg")
    }
}

@MainActor
struct BirdOfTheDayTests {
    private func page(_ items: [String], total: Int, number: Int = 0) -> Data {
        Data(#"{"content":[\#(items.joined(separator: ","))],"page":{"totalElements":\#(total)}}"#.utf8)
    }

    private func species(_ name: String, photo: Bool, license: String? = "CC BY", credit: String? = "Ada") -> String {
        let image = photo
            ? #"[{"imageUrl":"/uploads/\#(name).jpg","licenseCode":\#(license.map { "\"\($0)\"" } ?? "null"),"attribution":\#(credit.map { "\"\($0)\"" } ?? "null")}]"#
            : "[]"
        return #"{"id":"11111111-1111-1111-1111-111111111111","commonName":{"en":"\#(name)","tr":"\#(name)-tr"},"scientificName":"Avis \#(name)","description":{"en":"About \#(name)"},"images":\#(image)}"#
    }

    @Test func theSameBirdAllDayAndADifferentOneAnotherDay() {
        let calendar = Calendar(identifier: .gregorian)
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: Date(timeIntervalSince1970: 1_790_000_000))!
        let morning = noon.addingTimeInterval(-5 * 3600)
        let evening = noon.addingTimeInterval(5 * 3600)
        #expect(calendar.isDate(morning, inSameDayAs: evening))
        #expect(BirdOfTheDayFetcher.index(on: morning, total: 50) == BirdOfTheDayFetcher.index(on: evening, total: 50))
        #expect(BirdOfTheDayFetcher.index(on: morning, total: 50) != BirdOfTheDayFetcher.index(on: morning.addingTimeInterval(86_400), total: 50))
        #expect((0..<50).contains(BirdOfTheDayFetcher.index(on: morning, total: 50)))
        #expect(BirdOfTheDayFetcher.index(on: morning, total: 0) == 0)
    }

    @Test func picksTheBirdForTheDayInTheAppLanguageWithItsPhotoCredit() async throws {
        let date = Date(timeIntervalSince1970: 1_790_000_000)
        let target = BirdOfTheDayFetcher.index(on: date, total: 40)
        let bird = await BirdOfTheDayFetcher.fetch(on: date, language: "tr") { url in
            let requested = Int(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "page" }?.value ?? "") ?? -1
            return self.page([self.species(requested == target ? "Target" : "Other", photo: true)], total: 40, number: requested)
        }
        #expect(bird?.name == "Target-tr")
        #expect(bird?.summary == "About Target")
        #expect(bird?.id == UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        #expect(bird?.credit == "Ada · CC BY")
        #expect(bird?.photoURL?.absoluteString == "https://wingmark-backend.onrender.com/uploads/Target.jpg")
    }

    @Test func skipsASpeciesWithoutAPhotoAndOmitsTheCreditForOwnUploads() async {
        let date = Date(timeIntervalSince1970: 1_790_000_000)
        let target = BirdOfTheDayFetcher.index(on: date, total: 10)
        let bird = await BirdOfTheDayFetcher.fetch(on: date, language: "en") { url in
            let requested = Int(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "page" }?.value ?? "") ?? -1
            return self.page([requested == target ? self.species("Bare", photo: false) : self.species("Own", photo: true, license: nil, credit: nil)],
                             total: 10)
        }
        #expect(bird?.name == "Own")
        #expect(bird?.credit == nil)
    }

    @Test func failsQuietlyWhenTheServerIsUnreachableOrEmpty() async {
        let offline = await BirdOfTheDayFetcher.fetch(on: .now, language: "en") { _ in throw URLError(.notConnectedToInternet) }
        #expect(offline == nil)
        let empty = await BirdOfTheDayFetcher.fetch(on: .now, language: "en") { _ in self.page([], total: 0) }
        #expect(empty == nil)
    }

    @Test func theLastBirdIsKeptForOfflineUseButNeverMixedWithPersonalData() {
        let directory = FileManager.default.temporaryDirectory.appending(path: "bird-tests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = SharedStore(directory: directory)
        let bird = BirdOfTheDay(id: nil, name: "House Sparrow", scientificName: nil, summary: nil, photoURL: nil, credit: nil)
        store.writeBird(bird, photo: Data([1]))
        store.clear()
        #expect(store.readBird() == bird)
    }
}
