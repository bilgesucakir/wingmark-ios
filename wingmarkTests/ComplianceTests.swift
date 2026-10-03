import Foundation
import Testing
@testable import wingmark

struct ComplianceTests {
    private func makeSession(
        tokens: TokenPair? = nil,
        wipe: @escaping () -> Void = {},
        handler: @escaping (URLRequest) async throws -> MockTransport.Reply
    ) -> (AuthSession, MockTransport) {
        let transport = MockTransport(handler: handler)
        let client = APIClient(baseURL: URL(string: "https://api.test")!, tokenStore: InMemoryTokenStore(tokens), transport: transport)
        return (AuthSession(client: client, wipeLocalData: wipe), transport)
    }

    private func tokenJSON(_ pair: TokenPair, pending: String) -> String {
        #"{"accessToken":"\#(pair.accessToken)","refreshToken":"\#(pair.refreshToken)","expiresInMs":900000,"pendingConsents":\#(pending)}"#
    }

    @Test func pendingConsentsFromLoginClearOnceAccepted() async throws {
        let (session, transport) = makeSession { request in
            switch (request.httpMethod, request.url?.path) {
            case ("POST", "/api/auth/login"):
                .init(status: 200, body: self.tokenJSON(Fixtures.tokens("a"), pending: #"["TERMS"]"#))
            case (_, "/api/legal"):
                .init(status: 200, body: #"{"termsVersion":"2026-10","termsUrl":"https://example.com/terms","privacyVersion":null,"privacyUrl":null}"#)
            case ("POST", let path?) where path.hasSuffix("/consents"):
                .init(status: 200, body: #"{"pendingConsents":[]}"#)
            default:
                .init(status: 200, body: Fixtures.userJSON)
            }
        }
        await session.restore()
        try await session.logIn(email: "ada@example.com", password: "secret123")
        #expect(session.pendingConsents == [.terms])

        try await session.acceptPendingConsents(try await session.legalDocuments())

        #expect(session.pendingConsents.isEmpty)
        let post = try #require(transport.requests.last { $0.url?.path.hasSuffix("/consents") == true })
        #expect(post.jsonBody == ["type": "TERMS", "version": "2026-10"])
    }

    @Test func unknownConsentTypeDoesNotBreakLogin() async throws {
        let (session, _) = makeSession { request in
            request.url?.path == "/api/auth/login"
                ? .init(status: 200, body: self.tokenJSON(Fixtures.tokens("a"), pending: #"["TERMS","COOKIES"]"#))
                : .init(status: 200, body: Fixtures.userJSON)
        }
        await session.restore()
        try await session.logIn(email: "ada@example.com", password: "secret123")
        #expect(session.state == .signedIn(userId: Fixtures.userId))
        #expect(session.pendingConsents == [.terms])
    }

    @Test func tokenRefreshUpdatesPendingConsents() async {
        var profileCalls = 0
        let (session, _) = makeSession(tokens: Fixtures.tokens("a")) { request in
            if request.url?.path == "/api/auth/refresh" {
                return .init(status: 200, body: self.tokenJSON(Fixtures.tokens("b"), pending: #"["PRIVACY"]"#))
            }
            if request.url?.path.hasPrefix("/api/users/") == true, !request.url!.path.hasSuffix("/settings") {
                profileCalls += 1
                if profileCalls == 1 { return Fixtures.error(status: 401, code: "UNAUTHENTICATED") }
            }
            return .init(status: 200, body: request.url?.path.hasSuffix("/settings") == true
                ? #"{"unitPreference":"METRIC","locale":"en"}"# : Fixtures.userJSON)
        }
        await session.restore()
        #expect(session.pendingConsents == [.privacy])
    }

    @Test func deletingTheAccountWipesLocalData() async throws {
        var wiped = false
        let (session, _) = makeSession(tokens: Fixtures.tokens("a"), wipe: { wiped = true }) { request in
            request.httpMethod == "DELETE" ? .init(status: 204, body: "") : .init(status: 200, body: Fixtures.userJSON)
        }
        await session.restore()
        try await session.deleteAccount(password: "secret123")
        #expect(wiped)
        #expect(session.state == .signedOut)
        #expect(session.accountDeletedNotice)
    }

    @Test func failedDeletionKeepsLocalData() async throws {
        var wiped = false
        let (session, _) = makeSession(tokens: Fixtures.tokens("a"), wipe: { wiped = true }) { request in
            request.httpMethod == "DELETE" ? Fixtures.error(status: 403, code: "WRONG_PASSWORD") : .init(status: 200, body: Fixtures.userJSON)
        }
        await session.restore()
        await #expect(throws: APIError.self) { try await session.deleteAccount(password: "wrong") }
        #expect(!wiped)
    }

    @Test func exportIsSavedAsJSONFile() async throws {
        let body = #"{"exportedAt":"2026-10-02T10:00:00Z","profile":{},"settings":{},"birdLogs":[],"badges":[],"consents":[]}"#
        let (session, _) = makeSession(tokens: Fixtures.tokens("a")) { request in
            request.url?.path.hasSuffix("/export") == true ? .init(status: 200, body: body) : .init(status: 200, body: Fixtures.userJSON)
        }
        await session.restore()
        let file = try await session.exportData()
        #expect(file.lastPathComponent == "wingmark-data-export.json")
        #expect(try String(contentsOf: file, encoding: .utf8) == body)
        try? FileManager.default.removeItem(at: file)
    }

    @Test func registerSendsAcceptedVersionsOnlyWhenGiven() throws {
        let bare = AuthAPI.RegisterRequest(email: "a@b.co", password: "secret123", username: "ada", firstName: nil, lastName: nil)
        let bareJSON = try #require(JSONSerialization.jsonObject(with: JSONCoding.makeEncoder().encode(bare)) as? [String: Any])
        #expect(bareJSON["acceptedTermsVersion"] == nil)

        var accepted = bare
        accepted.acceptedTermsVersion = "2026-10"
        accepted.acceptedPrivacyVersion = "3"
        let json = try #require(JSONSerialization.jsonObject(with: JSONCoding.makeEncoder().encode(accepted)) as? [String: Any])
        #expect(json["acceptedTermsVersion"] as? String == "2026-10")
        #expect(json["acceptedPrivacyVersion"] as? String == "3")
    }

    @Test func onlyPublishedDocumentsNeedAccepting() throws {
        let json = #"{"termsVersion":null,"termsUrl":null,"privacyVersion":"1","privacyUrl":"https://example.com/privacy"}"#
        let legal = try JSONCoding.makeDecoder().decode(LegalDocuments.self, from: Data(json.utf8))
        #expect(legal.published == [.privacy])
        #expect(legal.url(of: .privacy)?.host() == "example.com")
        #expect(legal.url(of: .terms) == nil)
        #expect(LegalDocuments.unpublished.published.isEmpty)
    }

    @Test func speciesImagesDecodeLicenseFields() throws {
        let json = #"{"id":"00000000-0000-0000-0000-000000000001","lifeStage":"ADULT","gender":"MALE","imageUrl":"https://example.com/a.jpg","caption":null,"licenseCode":"CC-BY","attribution":"(c) Jane Doe","sourceUrl":"https://www.inaturalist.org/observations/1"}"#
        let image = try JSONCoding.makeDecoder().decode(SpeciesImage.self, from: Data(json.utf8))
        #expect(image.licenseCode == "CC-BY")
        #expect(image.attribution == "(c) Jane Doe")

        let ownUpload = #"{"id":"00000000-0000-0000-0000-000000000002","lifeStage":null,"gender":null,"imageUrl":"/uploads/x.jpg","caption":null}"#
        #expect(try JSONCoding.makeDecoder().decode(SpeciesImage.self, from: Data(ownUpload.utf8)).licenseCode == nil)
    }

    @Test func consentErrorsGetAUserMessage() {
        for code in ["TERMS_NOT_ACCEPTED", "PRIVACY_NOT_ACCEPTED", "CONSENT_VERSION_MISMATCH"] {
            let body = try? JSONCoding.makeDecoder().decode(APIErrorBody.self, from: Data(#"{"code":"\#(code)"}"#.utf8))
            #expect(body?.code != .unknown)
        }
    }

    @Test func rateLimitIsReportedWithRetryAfterAndNeverRefreshes() async throws {
        let (session, transport) = makeSession { request in
            var reply = Fixtures.error(status: 429, code: "RATE_LIMITED")
            reply.headers = ["Retry-After": "300"]
            return reply
        }
        await session.restore()
        do {
            try await session.logIn(email: "ada@example.com", password: "birdsong2026")
            Issue.record("expected a rate-limit error")
        } catch {
            #expect(error.isRateLimited)
            #expect(error.retryAfter == 300)
            #expect(error.userMessage == APIError.rateLimitMessage(retryAfter: 300))
        }
        #expect(transport.requests(to: "/api/auth/refresh").isEmpty)
        #expect(transport.requests.count == 1)
    }

    @Test func rateLimitWithoutBodyIsStillRecognized() async throws {
        let (session, _) = makeSession { _ in .init(status: 429, body: "", headers: ["Retry-After": "30"]) }
        await session.restore()
        await #expect(throws: APIError.self) { try await session.requestPasswordReset(email: "ada@example.com") }
        do {
            try await session.requestPasswordReset(email: "ada@example.com")
        } catch {
            #expect(error.isRateLimited)
            #expect(error.userMessage == APIError.rateLimitMessage(retryAfter: 30))
        }
    }

    @Test func passwordStrengthErrorsHaveTheirOwnMessages() {
        let weak = APIError.server(status: 400, body: APIErrorBody(status: 400, code: .weakPassword, message: nil, path: nil, validationErrors: nil))
        let breached = APIError.server(status: 400, body: APIErrorBody(status: 400, code: .passwordBreached, message: nil, path: nil, validationErrors: nil))
        let generic = APIError.server(status: 500, body: nil).userMessage
        #expect(weak.userMessage != generic && breached.userMessage != generic && weak.userMessage != breached.userMessage)
    }
}

struct ReinstallTests {
    @Test func freshInstallClearsLeftoverTokensOnce() throws {
        let defaults = try #require(UserDefaults(suiteName: "reinstall-\(UUID().uuidString)"))
        let store = InMemoryTokenStore(Fixtures.tokens("a"))
        LocalData.clearSessionFromPreviousInstall(store, defaults: defaults)
        #expect(store.tokens == nil)

        store.save(Fixtures.tokens("b"))
        LocalData.clearSessionFromPreviousInstall(store, defaults: defaults)
        #expect(store.tokens == Fixtures.tokens("b"))
    }
}
