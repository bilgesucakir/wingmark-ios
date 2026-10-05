import Foundation
import Testing
@testable import wingmark

@MainActor
struct BadgeTests {
    static let catalogJSON = """
    [{"id":"00000000-0000-0000-0000-000000000001","name":{"en":"First Flight"},"description":{"en":"Log a bird."},"icon":"🐦","criteriaType":"TOTAL_LOGS","criteriaValue":1,"criteriaMetadata":null,"tier":"BRONZE"},
     {"id":"00000000-0000-0000-0000-000000000002","name":{"en":"Explorer"},"description":null,"icon":"🔍","criteriaType":"UNIQUE_SPECIES","criteriaValue":5,"criteriaMetadata":null,"tier":"SILVER"},
     {"id":"00000000-0000-0000-0000-000000000003","name":{"en":"Legend"},"description":null,"icon":"👑","criteriaType":"TOTAL_LOGS","criteriaValue":100,"criteriaMetadata":null,"tier":"PLATINUM"}]
    """

    static func userJSON(firstEarned: Bool) -> String {
        """
        [{"badgeId":"00000000-0000-0000-0000-000000000001","badgeName":"First Flight","badgeIcon":"🐦","earned":\(firstEarned),"earnedAt":\(firstEarned ? "\"2026-09-30T10:00:00Z\"" : "null"),"progress":\(firstEarned ? 1 : 0),"targetValue":1},
         {"badgeId":"00000000-0000-0000-0000-000000000002","badgeName":"Explorer","badgeIcon":"🔍","earned":false,"earnedAt":null,"progress":3,"targetValue":5}]
        """
    }

    @Test func keepsTheServersOrderAndOmitsBadgesTheUserDoesNotHave() throws {
        let decoder = JSONCoding.makeDecoder()
        let catalog = try decoder.decode([CatalogBadge].self, from: Data(Self.catalogJSON.utf8))
        // The server's order puts the unearned Explorer first and leaves Legend out (it doesn't apply to this user).
        let userJSON = """
        [{"badgeId":"00000000-0000-0000-0000-000000000002","badgeName":"Explorer","badgeIcon":"🔍","earned":false,"earnedAt":null,"progress":3,"targetValue":5},
         {"badgeId":"00000000-0000-0000-0000-000000000001","badgeName":"First Flight","badgeIcon":"🐦","earned":true,"earnedAt":"2026-09-30T10:00:00Z","progress":1,"targetValue":1}]
        """
        let user = try decoder.decode([UserBadge].self, from: Data(userJSON.utf8))
        let merged = BadgeProgress.merge(catalog: catalog, user: user)

        // The earned First Flight moves ahead of the unearned Explorer; Legend stays hidden.
        #expect(merged.map(\.name) == ["First Flight", "Explorer"])
        #expect(merged[0].earned)
        #expect(merged[1].fraction == 0.6)
        #expect(merged[1].tier == .silver)
        #expect(merged[0].description == "Log a bird." && merged[1].description == nil)
    }

    @Test func earnedBadgesComeFirstAndKeepTheServerOrderWithinEachGroup() throws {
        func badge(_ n: Int, earned: Bool) -> String {
            let id = String(format: "00000000-0000-0000-0000-%012d", n)
            return #"{"badgeId":"\#(id)","badgeName":"b\#(n)","badgeIcon":"🐦","earned":\#(earned),"earnedAt":\#(earned ? "\"2026-09-30T10:00:00Z\"" : "null"),"progress":\#(earned ? 1 : 0),"targetValue":1}"#
        }
        // Server order b1 to b5; b3 and b1 are earned (b3 earned most recently).
        let json = "[" + [badge(1, earned: true), badge(2, earned: false), badge(3, earned: true), badge(4, earned: false), badge(5, earned: false)].joined(separator: ",") + "]"
        let user = try JSONCoding.makeDecoder().decode([UserBadge].self, from: Data(json.utf8))
        let merged = BadgeProgress.merge(catalog: [], user: user)
        #expect(merged.map(\.name) == ["b1", "b3", "b2", "b4", "b5"])
        #expect(merged.map(\.earned) == [true, true, false, false, false])
    }

    @Test func withNothingEarnedTheServerOrderIsUnchanged() throws {
        let decoder = JSONCoding.makeDecoder()
        let catalog = try decoder.decode([CatalogBadge].self, from: Data(Self.catalogJSON.utf8))
        let user = try decoder.decode([UserBadge].self, from: Data(Self.userJSON(firstEarned: false).utf8))
        #expect(BadgeProgress.merge(catalog: catalog, user: user).map(\.name) == ["First Flight", "Explorer"])
    }

    @Test func fallsBackToBronzeForAnUnknownTierAndIgnoresDuplicates() throws {
        let decoder = JSONCoding.makeDecoder()
        let catalog = try decoder.decode([CatalogBadge].self, from: Data(Self.catalogJSON.utf8))
        let userJSON = """
        [{"badgeId":"00000000-0000-0000-0000-000000000003","badgeName":"Legend","badgeIcon":"👑","earned":false,"earnedAt":null,"progress":0,"targetValue":100},
         {"badgeId":"00000000-0000-0000-0000-000000000003","badgeName":"Legend","badgeIcon":"👑","earned":false,"earnedAt":null,"progress":0,"targetValue":100}]
        """
        let user = try decoder.decode([UserBadge].self, from: Data(userJSON.utf8))
        let merged = BadgeProgress.merge(catalog: catalog, user: user)

        #expect(merged.count == 1)
        #expect(merged[0].tier == .bronze)
        #expect(merged[0].target == 100 && merged[0].progress == 0)
    }

    @Test func aBadgeThatAppearsLaterJoinsTheListInTheServersPosition() throws {
        let decoder = JSONCoding.makeDecoder()
        let catalog = try decoder.decode([CatalogBadge].self, from: Data(Self.catalogJSON.utf8))
        let without = try decoder.decode([UserBadge].self, from: Data(Self.userJSON(firstEarned: false).utf8))
        #expect(BadgeProgress.merge(catalog: catalog, user: without).count == 2)

        // Setting a favorite species makes the server add a badge; the list grows without an app change.
        let with = try decoder.decode([UserBadge].self, from: Data("""
        [{"badgeId":"00000000-0000-0000-0000-000000000003","badgeName":"Legend","badgeIcon":"👑","earned":false,"earnedAt":null,"progress":2,"targetValue":100},
         {"badgeId":"00000000-0000-0000-0000-000000000001","badgeName":"First Flight","badgeIcon":"🐦","earned":false,"earnedAt":null,"progress":0,"targetValue":1}]
        """.utf8))
        #expect(BadgeProgress.merge(catalog: catalog, user: with).map(\.name) == ["Legend", "First Flight"])
    }

    @Test func detectsNewlyEarnedBadgesOnReload() async {
        var firstEarned = false
        let transport = MockTransport { request in
            switch request.url?.path {
            case "/api/badges/catalog": return .init(status: 200, body: Self.catalogJSON)
            case let path? where path.hasPrefix("/api/badges/user"): return .init(status: 200, body: Self.userJSON(firstEarned: firstEarned))
            case let path? where path.hasSuffix("/settings"): return .init(status: 200, body: #"{"unitPreference":"METRIC","locale":"en"}"#)
            default: return .init(status: 200, body: Fixtures.userJSON)
            }
        }
        let client = APIClient(baseURL: URL(string: "https://api.test")!,
                               tokenStore: InMemoryTokenStore(Fixtures.tokens("a")), transport: transport)
        let session = AuthSession(client: client)
        await session.restore()
        let store = BadgesStore(session: session)

        await store.load()
        #expect(store.newlyEarned.isEmpty)
        #expect(store.earnedCount == 0)

        firstEarned = true
        await store.load()
        #expect(store.newlyEarned.map(\.name) == ["First Flight"])
        #expect(store.earnedCount == 1)
    }
}
