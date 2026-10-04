import Foundation
import Testing
@testable import wingmark

@MainActor
struct APIClientTests {
    private let base = URL(string: "https://api.test")!

    private func makeClient(tokens: TokenPair?, transport: MockTransport) -> (APIClient, InMemoryTokenStore) {
        let store = InMemoryTokenStore(tokens)
        let client = APIClient(baseURL: base, tokenStore: store, transport: transport, languageCode: { "tr" })
        return (client, store)
    }

    @Test func sendsHeadersAndDecodes() async throws {
        let transport = MockTransport { _ in .init(status: 200, body: Fixtures.userJSON) }
        let (client, _) = makeClient(tokens: Fixtures.tokens("a"), transport: transport)

        let user = try await client.send(AuthAPI.user(id: Fixtures.userId))

        #expect(user.username == "ada")
        let request = try #require(transport.requests.first)
        #expect(request.url?.absoluteString == "https://api.test/api/users/3f2504e0-4f89-11d3-9a0c-0305e82c3301")
        #expect(request.value(forHTTPHeaderField: "Accept-Language") == "tr")
        #expect(request.bearerToken == Fixtures.tokens("a").accessToken)
    }

    @Test func publicEndpointsSendNoToken() async throws {
        let transport = MockTransport { _ in .init(status: 202, body: "") }
        let (client, _) = makeClient(tokens: Fixtures.tokens("a"), transport: transport)

        _ = try await client.send(AuthAPI.forgotPassword(email: "ada@example.com"))

        #expect(transport.requests.first?.bearerToken == nil)
        #expect(transport.requests.first?.jsonBody == ["email": "ada@example.com"])
    }

    @Test func mapsErrorBodyToTypedError() async {
        let transport = MockTransport { _ in Fixtures.error(status: 401, code: "INVALID_CREDENTIALS") }
        let (client, _) = makeClient(tokens: nil, transport: transport)

        await #expect {
            try await client.send(AuthAPI.login(email: "a", password: "b"))
        } throws: { error in
            (error as? APIError)?.code == .invalidCredentials
        }
        #expect(transport.requests.count == 1)
    }

    @Test func refreshesOnceAndRetries() async throws {
        let old = Fixtures.tokens("old"), new = Fixtures.tokens("new")
        let transport = MockTransport { request in
            if request.url?.path == "/api/auth/refresh" {
                #expect(request.jsonBody["refreshToken"] == old.refreshToken)
                return .init(status: 200, body: Fixtures.tokenJSON(new))
            }
            return request.bearerToken == new.accessToken
                ? .init(status: 200, body: Fixtures.userJSON)
                : Fixtures.error(status: 401, code: "UNAUTHENTICATED")
        }
        let (client, store) = makeClient(tokens: old, transport: transport)

        let user = try await client.send(AuthAPI.user(id: Fixtures.userId))

        #expect(user.username == "ada")
        #expect(store.tokens == new)
        #expect(transport.requests(to: "/api/auth/refresh").count == 1)
    }

    @Test func concurrentUnauthorizedRequestsShareOneRefresh() async throws {
        let old = Fixtures.tokens("old"), new = Fixtures.tokens("new")
        let transport = MockTransport { request in
            await Task.yield()
            if request.url?.path == "/api/auth/refresh" {
                for _ in 0..<5 { await Task.yield() }
                return .init(status: 200, body: Fixtures.tokenJSON(new))
            }
            return request.bearerToken == new.accessToken
                ? .init(status: 200, body: Fixtures.userJSON)
                : Fixtures.error(status: 401, code: "UNAUTHENTICATED")
        }
        let (client, store) = makeClient(tokens: old, transport: transport)

        let tasks = (0..<3).map { _ in
            Task { try await client.send(AuthAPI.user(id: Fixtures.userId)) }
        }
        var users: [UserProfile] = []
        for task in tasks { users.append(try await task.value) }

        #expect(users.allSatisfy { $0.username == "ada" })
        #expect(transport.requests(to: "/api/auth/refresh").count == 1)
        #expect(store.tokens == new)
    }

    @Test func rejectedRefreshEndsTheSession() async {
        let transport = MockTransport { request in
            request.url?.path == "/api/auth/refresh"
                ? Fixtures.error(status: 401, code: "INVALID_OR_EXPIRED_TOKEN")
                : Fixtures.error(status: 401, code: "UNAUTHENTICATED")
        }
        let (client, store) = makeClient(tokens: Fixtures.tokens("old"), transport: transport)
        var expiredCalls = 0
        client.onSessionExpired = { expiredCalls += 1 }

        await #expect {
            try await client.send(AuthAPI.user(id: Fixtures.userId))
        } throws: { error in
            if case .sessionExpired = error as? APIError { return true }
            return false
        }
        #expect(store.tokens == nil)
        #expect(expiredCalls == 1)
    }

    @Test func stillUnauthorizedAfterRefreshEndsTheSession() async {
        let transport = MockTransport { request in
            request.url?.path == "/api/auth/refresh"
                ? .init(status: 200, body: Fixtures.tokenJSON(Fixtures.tokens("new")))
                : Fixtures.error(status: 401, code: "UNAUTHENTICATED")
        }
        let (client, store) = makeClient(tokens: Fixtures.tokens("old"), transport: transport)

        await #expect(throws: APIError.self) {
            try await client.send(AuthAPI.user(id: Fixtures.userId))
        }
        #expect(store.tokens == nil)
        #expect(transport.requests(to: "/api/users/3f2504e0-4f89-11d3-9a0c-0305e82c3301").count == 2)
    }

    @Test func offlineRefreshKeepsTheSession() async {
        let old = Fixtures.tokens("old")
        let transport = MockTransport { request in
            if request.url?.path == "/api/auth/refresh" { throw URLError(.notConnectedToInternet) }
            return Fixtures.error(status: 401, code: "UNAUTHENTICATED")
        }
        let (client, store) = makeClient(tokens: old, transport: transport)

        await #expect {
            try await client.send(AuthAPI.user(id: Fixtures.userId))
        } throws: { error in
            if case .network(let urlError) = error as? APIError { return urlError.code == .notConnectedToInternet }
            return false
        }
        #expect(store.tokens == old)
    }

    @Test func assetURLResolvesRelativeUploads() {
        let (client, _) = makeClient(tokens: nil, transport: MockTransport { _ in .init(status: 200, body: "") })
        #expect(client.assetURL(for: "/uploads/a.jpg")?.absoluteString == "https://api.test/uploads/a.jpg")
        #expect(client.assetURL(for: "https://cdn.test/b.jpg")?.absoluteString == "https://cdn.test/b.jpg")
    }
}
