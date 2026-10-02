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

    @Test func updateSettingsSendsLocaleAndKeepsStoredUnits() async throws {
        let transport = MockTransport { request in
            if request.url?.path.hasSuffix("/settings") == true, request.httpMethod == "PUT" {
                return .init(status: 200, body: #"{"unitPreference":"IMPERIAL","locale":"tr"}"#)
            }
            if request.url?.path.hasSuffix("/settings") == true {
                return .init(status: 200, body: #"{"unitPreference":"IMPERIAL","locale":"en"}"#)
            }
            return .init(status: 200, body: Fixtures.userJSON)
        }
        let client = APIClient(baseURL: URL(string: "https://api.test")!,
                               tokenStore: InMemoryTokenStore(Fixtures.tokens("a")), transport: transport)
        let session = AuthSession(client: client)
        await session.restore()
        #expect(session.settings == UserSettings(unitPreference: .imperial, locale: "en"))

        try await session.updateSettings(locale: "tr")

        let put = try #require(transport.requests.last { $0.httpMethod == "PUT" })
        let body = try #require(put.httpBody.flatMap { try JSONSerialization.jsonObject(with: $0) as? [String: String] })
        #expect(body == ["unitPreference": "IMPERIAL", "locale": "tr"])
        #expect(session.settings?.locale == "tr")
    }

    @Test func legacyProfileWithoutCreatedAtDecodes() throws {
        let json = Fixtures.userJSON.replacingOccurrences(of: #""createdAt":"2026-09-12T10:11:12.345678Z""#, with: #""createdAt":null"#)
        let profile = try JSONCoding.makeDecoder().decode(UserProfile.self, from: Data(json.utf8))
        #expect(profile.createdAt == nil)
        #expect(profile.username == "ada")
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

struct UnitConversionTests {
    private let us = Locale(identifier: "en_US")

    @Test func convertsCentimetreRangesToInches() {
        let text = UnitPreference.imperial.convertingMeasurements(in: "12.5-14cm, wingspan 20-22cm", locale: us)
        #expect(text == "4.9–5.5 in, wingspan 7.9–8.7 in")
    }

    @Test func handlesTurkishDecimalsAndMetres() {
        let text = UnitPreference.imperial.convertingMeasurements(in: "12,5-14 cm, kanat açıklığı 1,2 m", locale: us)
        #expect(text == "4.9–5.5 in, kanat açıklığı 3.9 ft")
    }

    @Test func metricLeavesTextAlone() {
        #expect(UnitPreference.metric.convertingMeasurements(in: "12.5-14cm", locale: us) == "12.5-14cm")
    }

    @Test func ignoresWordsThatStartWithM() {
        #expect(UnitPreference.imperial.convertingMeasurements(in: "lives 5 months", locale: us) == "lives 5 months")
    }

    @Test func convertsWeightsToOuncesAndPounds() {
        let text = UnitPreference.imperial.convertingMeasurements(in: "11-14 cm long, about 30 g", locale: us)
        #expect(text == "4.3–5.5 in long, about 1.1 oz")
        #expect(UnitPreference.imperial.convertingMeasurements(in: "1-1,4 kg", locale: us) == "2.2–3.1 lb")
    }

    @Test func ignoresWordsThatStartWithG() {
        #expect(UnitPreference.imperial.convertingMeasurements(in: "yaklaşık 5 gün", locale: us) == "yaklaşık 5 gün")
    }
}
