import Foundation
import Testing
@testable import wingmark

@MainActor
struct AuthSessionTests {
    private func makeSession(
        tokens: TokenPair? = nil,
        handler: @escaping (URLRequest) async throws -> MockTransport.Reply
    ) -> (AuthSession, InMemoryTokenStore, MockTransport) {
        let store = InMemoryTokenStore(tokens)
        let transport = MockTransport(handler: handler)
        let client = APIClient(baseURL: URL(string: "https://api.test")!, tokenStore: store, transport: transport)
        return (AuthSession(client: client), store, transport)
    }

    @Test func restoreWithoutTokensIsSignedOut() async {
        let (session, _, transport) = makeSession { _ in .init(status: 500, body: "") }
        await session.restore()
        #expect(session.state == .signedOut)
        #expect(transport.requests.isEmpty)
    }

    @Test func restoreWithTokensSignsInAndLoadsProfile() async {
        let (session, _, _) = makeSession(tokens: Fixtures.tokens("a")) { _ in
            .init(status: 200, body: Fixtures.userJSON)
        }
        await session.restore()
        #expect(session.state == .signedIn(userId: Fixtures.userId))
        #expect(session.profile?.username == "ada")
    }

    @Test func restoreOfflineStaysSignedIn() async {
        let (session, _, _) = makeSession(tokens: Fixtures.tokens("a")) { _ in
            throw URLError(.notConnectedToInternet)
        }
        await session.restore()
        #expect(session.state == .signedIn(userId: Fixtures.userId))
        #expect(session.profile == nil)
    }

    @Test func loginStoresTokensAndSignsIn() async throws {
        let (session, store, _) = makeSession { request in
            request.url?.path == "/api/auth/login"
                ? .init(status: 200, body: Fixtures.tokenJSON(Fixtures.tokens("a")))
                : .init(status: 200, body: Fixtures.userJSON)
        }
        await session.restore()

        try await session.logIn(email: "ada@example.com", password: "secret123")

        #expect(session.state == .signedIn(userId: Fixtures.userId))
        #expect(store.tokens == Fixtures.tokens("a"))
        #expect(session.profile?.email == "ada@example.com")
    }

    @Test func unverifiedLoginNeedsVerification() async throws {
        let (session, store, _) = makeSession { _ in Fixtures.error(status: 403, code: "EMAIL_NOT_VERIFIED") }
        await session.restore()

        try await session.logIn(email: "ada@example.com", password: "secret123")

        #expect(session.state == .needsVerification(email: "ada@example.com"))
        #expect(store.tokens == nil)
    }

    @Test func wrongCredentialsThrow() async {
        let (session, _, _) = makeSession { _ in Fixtures.error(status: 401, code: "INVALID_CREDENTIALS") }
        await session.restore()

        await #expect {
            try await session.logIn(email: "ada@example.com", password: "nope")
        } throws: { ($0 as? APIError)?.code == .invalidCredentials }
        #expect(session.state == .signedOut)
    }

    @Test func registerNeedsVerification() async throws {
        let (session, store, _) = makeSession { _ in
            .init(status: 201, body: #"{"userId":"3f2504e0-4f89-11d3-9a0c-0305e82c3301","email":"ada@example.com","username":"ada","emailVerified":false,"message":"x"}"#)
        }
        await session.restore()

        try await session.register(.init(email: "ada@example.com", password: "secret123", username: "ada", firstName: nil, lastName: nil))

        #expect(session.state == .needsVerification(email: "ada@example.com"))
        #expect(store.tokens == nil)
    }

    @Test func changePasswordReplacesTokens() async throws {
        let (session, store, _) = makeSession(tokens: Fixtures.tokens("a")) { request in
            request.url?.path.hasSuffix("/password") == true
                ? .init(status: 200, body: Fixtures.tokenJSON(Fixtures.tokens("b")))
                : .init(status: 200, body: Fixtures.userJSON)
        }
        await session.restore()

        try await session.changePassword(current: "secret123", new: "secret456")

        #expect(store.tokens == Fixtures.tokens("b"))
        #expect(session.state == .signedIn(userId: Fixtures.userId))
    }

    @Test func logoutWipesTokensAndRevokesRefreshToken() async {
        let (session, store, transport) = makeSession(tokens: Fixtures.tokens("a")) { request in
            request.url?.path == "/api/auth/logout" ? .init(status: 204, body: "") : .init(status: 200, body: Fixtures.userJSON)
        }
        await session.restore()

        await session.logOut()

        #expect(session.state == .signedOut)
        #expect(store.tokens == nil)
        #expect(transport.requests(to: "/api/auth/logout").first?.jsonBody["refreshToken"] == "refresh-a")
    }

    @Test func serverEndingTheSessionSignsOut() async {
        let (session, store, _) = makeSession(tokens: Fixtures.tokens("a")) { request in
            request.url?.path == "/api/auth/refresh"
                ? Fixtures.error(status: 401, code: "INVALID_OR_EXPIRED_TOKEN")
                : Fixtures.error(status: 401, code: "UNAUTHENTICATED")
        }
        await session.restore()

        #expect(session.state == .signedOut)
        #expect(session.sessionExpiredNotice)
        #expect(store.tokens == nil)
    }
}
