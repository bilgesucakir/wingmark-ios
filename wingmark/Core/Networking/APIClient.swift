import Foundation

protocol HTTPTransport {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

struct URLSessionTransport: HTTPTransport {
    let session: URLSession

    init(timeout: TimeInterval = AppConfig.requestTimeout) {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = timeout
        configuration.urlCache = URLCache(memoryCapacity: 32 << 20, diskCapacity: 256 << 20)
        session = URLSession(configuration: configuration)
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        return (data, http)
    }
}

final class APIClient {
    let baseURL: URL
    let tokenStore: TokenStore
    private let transport: HTTPTransport
    private let languageCode: () -> String
    private var refreshTask: Task<TokenPair, Error>?

    var onSessionExpired: (() -> Void)?

    init(
        baseURL: URL = AppConfig.baseURL,
        tokenStore: TokenStore,
        transport: HTTPTransport = URLSessionTransport(),
        languageCode: @escaping () -> String = { AppLanguage.current.resolvedCode }
    ) {
        self.baseURL = baseURL
        self.tokenStore = tokenStore
        self.transport = transport
        self.languageCode = languageCode
    }

    func send<Response>(_ endpoint: Endpoint<Response>) async throws(APIError) -> Response {
        try await sendReturningResponse(endpoint).value
    }

    func sendReturningResponse<Response>(
        _ endpoint: Endpoint<Response>
    ) async throws(APIError) -> (value: Response, response: HTTPURLResponse) {
        let (data, response) = try await perform(endpoint, mayRefresh: true)
        return (try decode(Response.self, from: data), response)
    }

    func assetURL(for path: String) -> URL? {
        if let url = URL(string: path), url.scheme != nil { return url }
        return URL(string: path, relativeTo: baseURL)?.absoluteURL
    }

    // MARK: - Request pipeline

    private func perform<Response>(
        _ endpoint: Endpoint<Response>,
        mayRefresh: Bool
    ) async throws(APIError) -> (Data, HTTPURLResponse) {
        var tokens: TokenPair?
        if endpoint.requiresAuth {
            // Wait for a running refresh instead of sending stale tokens.
            if let refreshTask { _ = try? await refreshTask.value }
            guard let stored = tokenStore.load() else {
                endSession()
                throw .sessionExpired
            }
            tokens = stored
        }

        let (data, response) = try await transportSend(makeRequest(endpoint, accessToken: tokens?.accessToken))

        if response.statusCode == 401, let tokens {
            guard mayRefresh else {
                endSession()
                throw .sessionExpired
            }
            try await refreshTokens(replacing: tokens)
            return try await perform(endpoint, mayRefresh: false)
        }

        guard (200..<300).contains(response.statusCode) else {
            let body = try? JSONCoding.makeDecoder().decode(APIErrorBody.self, from: data)
            throw .server(status: response.statusCode, body: body)
        }
        return (data, response)
    }

    private func refreshTokens(replacing staleTokens: TokenPair) async throws(APIError) {
        if let current = tokenStore.load(), current != staleTokens { return }

        let task: Task<TokenPair, Error>
        if let refreshTask {
            task = refreshTask
        } else {
            // Saving inside the task means waiters never resume with stale tokens.
            task = Task { [refreshToken = staleTokens.refreshToken] in
                defer { self.refreshTask = nil }
                let tokens = try await self.requestNewTokens(refreshToken: refreshToken)
                self.tokenStore.save(tokens)
                return tokens
            }
            refreshTask = task
        }

        do {
            _ = try await task.value
        } catch {
            let apiError = error as? APIError ?? .decoding(String(describing: error))
            // Offline or timeout keeps the session.
            if apiError.isAuthRejection || tokenStore.load() == nil {
                endSession()
                throw .sessionExpired
            }
            throw apiError
        }
    }

    private func requestNewTokens(refreshToken: String) async throws(APIError) -> TokenPair {
        let (data, _) = try await perform(AuthAPI.refresh(refreshToken: refreshToken), mayRefresh: false)
        return try decode(TokenPair.self, from: data)
    }

    private func endSession() {
        let hadTokens = tokenStore.load() != nil
        tokenStore.clear()
        if hadTokens { onSessionExpired?() }
    }

    private func makeRequest<Response>(_ endpoint: Endpoint<Response>, accessToken: String?) -> URLRequest {
        var url = baseURL.appending(path: "api").appending(path: endpoint.path)
        if !endpoint.query.isEmpty {
            url.append(queryItems: endpoint.query)
        }
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(languageCode(), forHTTPHeaderField: "Accept-Language")
        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        switch endpoint.body {
        case .json(let data):
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = data
        case .raw(let data, let contentType):
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
            request.httpBody = data
        case nil:
            break
        }
        return request
    }

    private func transportSend(_ request: URLRequest) async throws(APIError) -> (Data, HTTPURLResponse) {
        do {
            return try await transport.send(request)
        } catch let error as URLError {
            throw .network(error)
        } catch is CancellationError {
            throw .network(URLError(.cancelled))
        } catch {
            throw .network(URLError(.unknown))
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws(APIError) -> T {
        if T.self == EmptyResponse.self, let empty = EmptyResponse() as? T { return empty }
        do {
            return try JSONCoding.makeDecoder().decode(T.self, from: data)
        } catch {
            throw .decoding(String(describing: error))
        }
    }
}
