import Foundation

struct Endpoint<Response: Decodable> {
    enum Method: String, Sendable {
        case get = "GET", post = "POST", put = "PUT", delete = "DELETE"
    }

    enum Body: Sendable {
        case json(Data)
        case raw(Data, contentType: String)
    }

    var method: Method
    var path: String
    var query: [URLQueryItem] = []
    var body: Body?
    var requiresAuth: Bool = true

    init(_ method: Method, _ path: String, query: [URLQueryItem] = [], body: Body? = nil, requiresAuth: Bool = true) {
        self.method = method
        self.path = path
        self.query = query
        self.body = body
        self.requiresAuth = requiresAuth
    }

    init(_ method: Method, _ path: String, query: [URLQueryItem] = [], json: some Encodable, requiresAuth: Bool = true) {
        let data: Data
        do {
            data = try JSONCoding.makeEncoder().encode(json)
        } catch {
            assertionFailure("Couldn't encode request body for \(path): \(error)")
            data = Data()
        }
        self.init(method, path, query: query, body: .json(data), requiresAuth: requiresAuth)
    }
}

struct EmptyResponse: Decodable, Sendable {}
