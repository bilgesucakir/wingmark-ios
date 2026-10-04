import Foundation
import Testing
@testable import wingmark

@MainActor
struct DecodingTests {
    @Test func userProfileDecodesMicrosecondDates() throws {
        let user = try JSONCoding.makeDecoder().decode(UserProfile.self, from: Data(Fixtures.userJSON.utf8))
        #expect(user.id == Fixtures.userId)
        #expect(user.displayName == "Ada")
        #expect(user.profilePicture == "avatar-3")
        #expect(user.role == .user)
        let components = Calendar(identifier: .gregorian).dateComponents(in: .gmt, from: try #require(user.createdAt))
        #expect(components.year == 2026 && components.hour == 10 && components.second == 12)
    }

    @Test(arguments: [
        "2026-09-30T08:00:00Z",
        "2026-09-30T08:00:00.1Z",
        "2026-09-30T08:00:00.123Z",
        "2026-09-30T08:00:00.123456Z",
        "2026-09-30T08:00:00.123456789Z",
        "2026-09-30T11:00:00.5+03:00",
    ])
    func parsesISO8601Variants(_ string: String) throws {
        let date = try #require(JSONCoding.parseDate(string))
        let components = Calendar(identifier: .gregorian).dateComponents(in: .gmt, from: date)
        #expect(components.hour == 8)
    }

    @Test func tokenPairIgnoresExpiry() throws {
        let json = Fixtures.tokenJSON(Fixtures.tokens("a"))
        let pair = try JSONCoding.makeDecoder().decode(TokenPair.self, from: Data(json.utf8))
        #expect(pair == Fixtures.tokens("a"))
    }

    @Test func errorBodyDecodesKnownAndUnknownCodes() throws {
        let known = try JSONCoding.makeDecoder().decode(
            APIErrorBody.self,
            from: Data(Fixtures.error(status: 400, code: "VALIDATION_FAILED", validationErrors: #"{"email":"bad"}"#).body.utf8)
        )
        #expect(known.code == .validationFailed)
        #expect(known.validationErrors == ["email": "bad"])

        let unknown = try JSONCoding.makeDecoder().decode(
            APIErrorBody.self, from: Data(Fixtures.error(status: 418, code: "BRAND_NEW_CODE").body.utf8)
        )
        #expect(unknown.code == .unknown)
    }

    @Test func jwtSubjectIsTheUserId() {
        #expect(JWT.subject(of: Fixtures.accessToken()) == Fixtures.userId)
        #expect(JWT.subject(of: "not-a-jwt") == nil)
    }
}
