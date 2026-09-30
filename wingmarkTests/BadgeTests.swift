import Foundation
import Testing
@testable import wingmark

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

    @Test func mergesCatalogWithProgressAndSorts() throws {
        let decoder = JSONCoding.makeDecoder()
        let catalog = try decoder.decode([CatalogBadge].self, from: Data(Self.catalogJSON.utf8))
        let user = try decoder.decode([UserBadge].self, from: Data(Self.userJSON(firstEarned: true).utf8))
        let merged = BadgeProgress.merge(catalog: catalog, user: user)

        #expect(merged.map(\.name) == ["First Flight", "Explorer", "Legend"])
        #expect(merged[0].earned)
        #expect(merged[1].fraction == 0.6)
        #expect(merged[2].target == 100 && merged[2].progress == 0)
        #expect(merged[2].tier == .bronze)
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
