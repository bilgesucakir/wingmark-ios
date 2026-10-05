import Foundation
import Testing
@testable import wingmark

@MainActor
@Suite(.serialized)
struct AgeConfirmationTests {
    private func legal(_ extra: String = #","minimumAge":13"#) throws -> LegalDocuments {
        let json = #"{"termsVersion":null,"termsUrl":null,"privacyVersion":"2026-10-03","privacyUrl":"https://example.com/privacy"\#(extra)}"#
        return try JSONCoding.makeDecoder().decode(LegalDocuments.self, from: Data(json.utf8))
    }

    private func withLanguage(_ language: AppLanguage, _ body: () -> Void) {
        let previous = UserDefaults.standard.string(forKey: AppLanguage.storageKey)
        UserDefaults.standard.set(language.rawValue, forKey: AppLanguage.storageKey)
        body()
        UserDefaults.standard.set(previous, forKey: AppLanguage.storageKey)
    }

    @Test func readsTheMinimumAgeAsAnItemToConfirm() throws {
        let documents = try legal()
        #expect(documents.minimumAge == 13)
        #expect(documents.version(of: .age) == "13")
        #expect(documents.url(of: .age) == nil)
        #expect(documents.published == [.privacy, .age])
    }

    @Test func aServerWithoutMinimumAgeAsksForNothing() throws {
        let documents = try legal("")
        #expect(documents.minimumAge == nil)
        #expect(documents.version(of: .age) == nil)
        #expect(documents.published == [.privacy])
    }

    @Test func theLabelUsesTheServersNumberInBothLanguages() throws {
        let thirteen = try legal()
        let sixteen = try legal(#","minimumAge":16"#)
        var english: [String] = []
        var turkish: [String] = []
        withLanguage(.english) { english = [thirteen.acceptanceLabel(of: .age), sixteen.acceptanceLabel(of: .age)] }
        withLanguage(.turkish) { turkish = [thirteen.acceptanceLabel(of: .age), sixteen.acceptanceLabel(of: .age)] }
        #expect(english == ["I am 13 or older", "I am 16 or older"])
        #expect(turkish[0].contains("13") && turkish[1].contains("16"))
        #expect(turkish[0] != english[0])
    }

    @Test func registerSendsConfirmedAge13OnlyWhenConfirmed() throws {
        var request = AuthAPI.RegisterRequest(email: "a@b.co", password: "birdsong2026", username: "ada", firstName: nil, lastName: nil)
        let unconfirmed = try #require(JSONSerialization.jsonObject(with: JSONCoding.makeEncoder().encode(request)) as? [String: Any])
        #expect(unconfirmed["confirmedAge13"] == nil)
        request.confirmedAge13 = true
        let confirmed = try #require(JSONSerialization.jsonObject(with: JSONCoding.makeEncoder().encode(request)) as? [String: Any])
        #expect(confirmed["confirmedAge13"] as? Bool == true)
    }

    @Test func ageNotConfirmedHasItsOwnMessage() throws {
        let body = try JSONCoding.makeDecoder().decode(APIErrorBody.self, from: Data(#"{"code":"AGE_NOT_CONFIRMED","message":"server text"}"#.utf8))
        #expect(body.code == .ageNotConfirmed)
        let error = APIError.server(status: 400, body: body)
        #expect(error.userMessage == "Please confirm your age to create an account.")
        #expect(error.userMessage != APIError.server(status: 500, body: nil).userMessage)
    }

    @Test func ageOnlyIsDetectedForTheExistingUserScreen() {
        #expect([ConsentType.age].isAgeOnly)
        #expect(![ConsentType.age, .privacy].isAgeOnly)
        #expect(![ConsentType]().isAgeOnly)
    }

    @Test func consentsDecodeTheAgeType() throws {
        let json = #"[{"type":"AGE","version":"13","acceptedAt":"2026-10-06T10:00:00Z"}]"#
        let consents = try JSONCoding.makeDecoder().decode([Consent].self, from: Data(json.utf8))
        #expect(consents.first?.type == .age && consents.first?.version == "13")
    }

    @Test func anExistingUserIsAskedForAgeAndConfirmsItWithTheMinimumAge() async throws {
        let tokens = Fixtures.tokens("a")
        let transport = MockTransport { request in
            switch (request.httpMethod, request.url?.path) {
            case ("POST", "/api/auth/login"):
                .init(status: 200, body: #"{"accessToken":"\#(tokens.accessToken)","refreshToken":"\#(tokens.refreshToken)","expiresInMs":900000,"pendingConsents":["AGE"]}"#)
            case ("POST", let path?) where path.hasSuffix("/consents"):
                .init(status: 200, body: #"{"pendingConsents":[]}"#)
            default:
                .init(status: 200, body: Fixtures.userJSON)
            }
        }
        let client = APIClient(baseURL: URL(string: "https://api.test")!, tokenStore: InMemoryTokenStore(), transport: transport)
        let session = AuthSession(client: client, wipeLocalData: {})
        await session.restore()
        try await session.logIn(email: "ada@example.com", password: "birdsong2026")
        #expect(session.pendingConsents == [.age])

        try await session.acceptPendingConsents(try legal())

        #expect(session.pendingConsents.isEmpty)
        let post = try #require(transport.requests.last { $0.url?.path.hasSuffix("/consents") == true })
        #expect(post.jsonBody == ["type": "AGE", "version": "13"])
    }
}
