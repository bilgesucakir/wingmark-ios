import Foundation
import Testing
@testable import wingmark

struct ProfileTests {
    @Test func profileUpdateSendsEveryFieldIncludingNulls() throws {
        let profile = try JSONCoding.makeDecoder().decode(UserProfile.self, from: Data(Fixtures.userJSON.utf8))
        var update = AuthAPI.ProfileUpdate(profile)
        update.profilePicture = nil
        let object = try #require(JSONSerialization.jsonObject(with: JSONCoding.makeEncoder().encode(update)) as? [String: Any])
        #expect(object["firstName"] as? String == "Ada")
        #expect(object["lastName"] is NSNull)
        #expect(object["profilePicture"] is NSNull)
        #expect(object["favoriteSpeciesId"] is NSNull)
    }

    @Test func updateSettingsSendsBothFieldsAndCachesUnits() async throws {
        let transport = MockTransport { request in
            if request.url?.path.hasSuffix("/settings") == true, request.httpMethod == "PUT" {
                return .init(status: 200, body: #"{"unitPreference":"IMPERIAL","locale":"tr"}"#)
            }
            if request.url?.path.hasSuffix("/settings") == true {
                return .init(status: 200, body: #"{"unitPreference":"METRIC","locale":"en"}"#)
            }
            return .init(status: 200, body: Fixtures.userJSON)
        }
        let client = APIClient(baseURL: URL(string: "https://api.test")!,
                               tokenStore: InMemoryTokenStore(Fixtures.tokens("a")), transport: transport)
        let session = AuthSession(client: client)
        await session.restore()
        #expect(session.settings == UserSettings(unitPreference: .metric, locale: "en"))

        try await session.updateSettings(unitPreference: .imperial)

        let put = try #require(transport.requests.last { $0.httpMethod == "PUT" })
        let body = try #require(put.httpBody.flatMap { try JSONSerialization.jsonObject(with: $0) as? [String: String] })
        #expect(body == ["unitPreference": "IMPERIAL", "locale": "en"])
        #expect(session.settings?.unitPreference == .imperial)
        #expect(UnitPreference.current == .imperial)
        UnitPreference.current = .metric
    }

    @Test func formatsDistancesPerUnitPreference() {
        let us = Locale(identifier: "en_US")
        #expect(UnitPreference.metric.format(meters: 250, locale: us) == "250 m")
        #expect(UnitPreference.metric.format(meters: 2500, locale: us) == "2.5 km")
        #expect(UnitPreference.imperial.format(meters: 100, locale: us) == "328.1 ft")
        #expect(UnitPreference.imperial.format(meters: 3218.7, locale: us) == "2 mi")
        #expect(UnitPreference.metric.format(meters: 2500, locale: Locale(identifier: "tr_TR")).contains("2,5"))
    }

    @Test func presetKeysGetStableStyles() {
        #expect(AvatarPresets.isPreset("avatar-3"))
        #expect(!AvatarPresets.isPreset("/uploads/a.jpg"))
        #expect(AvatarPresets.style(for: "avatar-1").symbol == AvatarPresets.style(for: "avatar-1").symbol)
    }
}
