import CoreLocation
import Foundation
import Testing
@testable import wingmark

@MainActor
struct SecretBadgeTests {
    private let lockedId = "00000000-0000-0000-0000-0000000000a1"

    private func decode(_ json: String) throws -> [UserBadge] {
        try JSONCoding.makeDecoder().decode([UserBadge].self, from: Data(json.utf8))
    }

    private func regular(_ n: Int, earned: Bool) -> String {
        let id = String(format: "00000000-0000-0000-0000-%012d", n)
        return #"{"badgeId":"\#(id)","secret":false,"earned":\#(earned),"earnedAt":\#(earned ? "\"2026-09-30T10:00:00Z\"" : "null"),"badgeName":"b\#(n)","badgeIcon":"🐦","badgeDescription":"d\#(n)","tier":"SILVER","progress":1,"targetValue":3}"#
    }

    private var locked: String {
        #"{"badgeId":"\#(lockedId)","secret":true,"earned":false,"earnedAt":null,"badgeName":null,"badgeIcon":null,"badgeDescription":null,"tier":"GOLD","progress":null,"targetValue":null}"#
    }

    private var earnedSecret: String {
        #"{"badgeId":"\#(lockedId)","secret":true,"earned":true,"earnedAt":"2026-10-01T10:00:00Z","badgeName":"Early Bird","badgeIcon":"🌅","badgeDescription":"Log before 6.","tier":"GOLD","progress":1,"targetValue":1}"#
    }

    @Test func aLockedSecretDecodesWithNullsAndKeepsOnlyItsTier() throws {
        let merged = BadgeProgress.merge(catalog: [], user: try decode("[\(locked)]"))
        let badge = try #require(merged.first)
        #expect(badge.isLockedSecret && badge.isSecret)
        #expect(badge.name.isEmpty && badge.description == nil && badge.icon == nil)
        #expect(badge.tier == .gold)
        #expect(badge.progress == 0 && badge.target == 0)
    }

    @Test func aMissingSecretFlagMeansARegularBadge() throws {
        let json = #"[{"badgeId":"00000000-0000-0000-0000-000000000001","badgeName":"x","earned":false,"progress":0,"targetValue":2}]"#
        let badge = try #require(BadgeProgress.merge(catalog: [], user: try decode(json)).first)
        #expect(!badge.isSecret && !badge.isLockedSecret)
    }

    @Test func lockedSecretsGoLastAndMoveUpOnceEarned() throws {
        let before = BadgeProgress.merge(catalog: [], user: try decode("[\(locked),\(regular(1, earned: false)),\(regular(2, earned: true))]"))
        #expect(before.map(\.name) == ["b2", "b1", ""])
        #expect(before.last?.isLockedSecret == true)

        let after = BadgeProgress.merge(catalog: [], user: try decode("[\(earnedSecret),\(regular(1, earned: false)),\(regular(2, earned: true))]"))
        #expect(after.map(\.name) == ["Early Bird", "b2", "b1"])
    }

    @Test func earningARevealsItsRealDetailsUnderTheSameId() throws {
        let before = try #require(BadgeProgress.merge(catalog: [], user: try decode("[\(locked)]")).first)
        let after = try #require(BadgeProgress.merge(catalog: [], user: try decode("[\(earnedSecret)]")).first)
        #expect(before.id == after.id)
        #expect(!after.isLockedSecret && after.earned)
        #expect(after.name == "Early Bird" && after.icon == "🌅" && after.tier == .gold && after.description == "Log before 6.")
    }

    @Test func userListTextWinsOverTheCatalog() throws {
        let catalog = try JSONCoding.makeDecoder().decode([CatalogBadge].self, from: Data(BadgeTests.catalogJSON.utf8))
        let json = #"[{"badgeId":"00000000-0000-0000-0000-000000000001","secret":false,"earned":false,"badgeName":"Ilk Ucus","badgeDescription":"Bir kus kaydet.","tier":"GOLD","progress":0,"targetValue":1}]"#
        let badge = try #require(BadgeProgress.merge(catalog: catalog, user: try decode(json)).first)
        #expect(badge.name == "Ilk Ucus" && badge.description == "Bir kus kaydet." && badge.tier == .gold)
        #expect(badge.names["en"] == "First Flight")
    }

    @Test func theHeaderTotalIncludesHiddenSecretsByDefault() throws {
        #expect(BadgePolicy.hiddenSecretsCountInTotal && BadgePolicy.lockedSecretsLast)
    }

    @Test func diamondIsAHigherTierAndUnknownTiersStayBronze() throws {
        let tiers = try JSONDecoder().decode([BadgeTier].self, from: Data(#"["DIAMOND","PLATINUM","GOLD"]"#.utf8))
        #expect(tiers == [.diamond, .bronze, .gold])
        #expect(!BadgeTier.diamond.title.isEmpty && BadgeTier.diamond.title != BadgeTier.gold.title)
    }

    @Test func aLockedSecretNeverReachesTheWidget() throws {
        let secret = try #require(BadgeProgress.merge(catalog: [], user: try decode("[\(locked)]")).first)
        let done = try #require(BadgeProgress.merge(catalog: [], user: try decode("[\(regular(1, earned: true))]")).first)
        let summary = WidgetSync.summary(logs: [], badges: [done, secret], language: "en")
        #expect(summary.nextBadge == nil)
        #expect(summary.allBadgesEarned)
        let onlySecret = WidgetSync.summary(logs: [], badges: [secret], language: "en")
        #expect(!onlySecret.allBadgesEarned && onlySecret.nextBadge == nil)
    }

    @Test func sightingsSendTheirUTCOffsetOnCreateAndEdit() throws {
        let created = SightingFormModel(editing: nil)
        created.coordinate = CLLocationCoordinate2D(latitude: 41, longitude: 29)
        let createInput = try #require(created.makeInput())
        let expected = TimeZone.current.secondsFromGMT(for: .now) / 60
        #expect(abs((createInput.utcOffsetMinutes ?? 9999) - expected) <= 60)

        let encoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(createInput)) as? [String: Any]
        #expect(encoded?["utcOffsetMinutes"] is Int)

        let json = DiaryFixtures.logJSON(id: "11111111-1111-1111-1111-111111111111", observedAt: "2026-09-29T07:30:00Z")
            .replacingOccurrences(of: #""visibility":"PRIVATE""#, with: #""visibility":"PRIVATE","utcOffsetMinutes":-300"#)
        let log = try JSONCoding.makeDecoder().decode(BirdLog.self, from: Data(json.utf8))
        #expect(log.utcOffsetMinutes == -300)
        let edited = SightingFormModel(editing: log).makeInput()
        #expect(edited?.utcOffsetMinutes == -300)
        let oldLog = try JSONCoding.makeDecoder().decode(BirdLog.self, from: Data(DiaryFixtures.logJSON(id: "11111111-1111-1111-1111-111111111111", observedAt: "2026-09-29T07:30:00Z").utf8))
        let backfilled = SightingFormModel(editing: oldLog).makeInput()
        #expect(backfilled?.utcOffsetMinutes == TimeZone.current.secondsFromGMT(for: oldLog.observedAt) / 60)
    }
}
