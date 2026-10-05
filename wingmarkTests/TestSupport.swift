import Foundation
@testable import wingmark

final class MockTransport: HTTPTransport {
    struct Reply {
        var status: Int
        var body: String
        var headers: [String: String] = [:]
    }

    private(set) var requests: [URLRequest] = []
    var handler: (URLRequest) async throws -> Reply

    init(handler: @escaping (URLRequest) async throws -> Reply) {
        self.handler = handler
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let reply = try await handler(request)
        let response = HTTPURLResponse(
            url: request.url!, statusCode: reply.status, httpVersion: "HTTP/1.1", headerFields: reply.headers
        )!
        return (Data(reply.body.utf8), response)
    }

    func requests(to path: String) -> [URLRequest] {
        requests.filter { $0.url?.path == path }
    }
}

enum Fixtures {
    static let userId = UUID(uuidString: "3F2504E0-4F89-11D3-9A0C-0305E82C3301")!

    static func accessToken(sub: UUID = userId, nonce: String = "1") -> String {
        let payload = #"{"sub":"\#(sub.uuidString.lowercased())","n":"\#(nonce)"}"#
        let base64URL = Data(payload.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return "eyJhbGciOiJIUzI1NiJ9.\(base64URL).signature"
    }

    static func tokens(_ nonce: String) -> TokenPair {
        TokenPair(accessToken: accessToken(nonce: nonce), refreshToken: "refresh-\(nonce)")
    }

    static func tokenJSON(_ pair: TokenPair) -> String {
        #"{"accessToken":"\#(pair.accessToken)","refreshToken":"\#(pair.refreshToken)","expiresInMs":900000}"#
    }

    static func error(status: Int, code: String, validationErrors: String? = nil) -> MockTransport.Reply {
        var body = #"{"timestamp":"2026-09-30T08:00:00.123456Z","status":\#(status),"error":"x","code":"\#(code)","message":"server text","path":"/api/x""#
        if let validationErrors { body += #","validationErrors":\#(validationErrors)"# }
        body += "}"
        return .init(status: status, body: body)
    }

    static let userJSON = """
    {"id":"3f2504e0-4f89-11d3-9a0c-0305e82c3301","email":"ada@example.com","username":"ada",
     "firstName":"Ada","lastName":null,"profilePicture":"avatar-3","favoriteSpeciesId":null,
     "favoriteSpeciesName":null,"role":"USER","emailVerified":true,"createdAt":"2026-09-12T10:11:12.345678Z"}
    """
}

extension URLRequest {
    var bearerToken: String? {
        value(forHTTPHeaderField: "Authorization")?.replacingOccurrences(of: "Bearer ", with: "")
    }

    var jsonBody: [String: String] {
        guard let httpBody, let object = try? JSONSerialization.jsonObject(with: httpBody) as? [String: String]
        else { return [:] }
        return object
    }
}

extension Pause {
    /// A debounce that doesn't wait. Superseded work is still cancelled, so coalescing behaves the same.
    nonisolated static let immediate = Pause { _ in }
}

/// A pause that stays put until the test lets it go, and remembers how long each wait asked for.
@MainActor
final class GatedPause {
    private(set) var requested: [Duration] = []
    private var waiting: [CheckedContinuation<Void, Never>] = []

    var pause: Pause {
        Pause { [self] duration in await wait(duration) }
    }

    private func wait(_ duration: Duration) async {
        requested.append(duration)
        await withCheckedContinuation { waiting.append($0) }
    }

    /// Lets every waiting debounce continue. Cancelled ones then see they were superseded and stop.
    func release() {
        let continuations = waiting
        waiting = []
        continuations.forEach { $0.resume() }
    }

    /// Returns once `count` debounces are waiting.
    func waitUntilWaiting(count: Int) async {
        var attempts = 0
        while requested.count < count, attempts < 10_000 {
            await Task.yield()
            attempts += 1
        }
    }
}
