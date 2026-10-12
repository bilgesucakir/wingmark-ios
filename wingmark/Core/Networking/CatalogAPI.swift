import Foundation

enum BirdLogAPI {
    static func userLogs(userId: UUID, filter: DiaryFilter) -> Endpoint<[BirdLog]> {
        var query = filter.queryItems
        query.append(URLQueryItem(name: "sortDirection", value: filter.newestFirst ? "DESC" : "ASC"))
        return Endpoint(.get, "bird-logs/user/\(userId.uuidString.lowercased())", query: query)
    }

    static func log(id: UUID) -> Endpoint<BirdLog> {
        Endpoint(.get, "bird-logs/\(id.uuidString.lowercased())")
    }

    static func create(_ input: BirdLogInput) -> Endpoint<BirdLog> {
        Endpoint(.post, "bird-logs", json: input)
    }

    static func update(id: UUID, _ input: BirdLogInput) -> Endpoint<BirdLog> {
        Endpoint(.put, "bird-logs/\(id.uuidString.lowercased())", json: input)
    }

    static func delete(id: UUID) -> Endpoint<EmptyResponse> {
        Endpoint(.delete, "bird-logs/\(id.uuidString.lowercased())")
    }
}

enum SpeciesSort: String, CaseIterable, Identifiable, Sendable {
    case commonAscending, commonDescending, scientificAscending, scientificDescending

    var id: String { rawValue }

    var title: String {
        switch self {
        case .commonAscending: String(localized: "Name (A–Z)", bundle: .app)
        case .commonDescending: String(localized: "Name (Z–A)", bundle: .app)
        case .scientificAscending: String(localized: "Scientific Name (A–Z)", bundle: .app)
        case .scientificDescending: String(localized: "Scientific Name (Z–A)", bundle: .app)
        }
    }

    func parameter(language: String) -> String {
        switch self {
        case .commonAscending: "commonName.\(language),asc"
        case .commonDescending: "commonName.\(language),desc"
        case .scientificAscending: "scientificName,asc"
        case .scientificDescending: "scientificName,desc"
        }
    }
}

struct SpeciesRecording: Decodable, Sendable, Identifiable, Hashable {
    let id: String
    let recordingUrl: String
    let type: String?
    let quality: String?
    let recordist: String?
    let licenseUrl: String?
}

enum SeenFilter: String, CaseIterable, Identifiable, Sendable {
    case all, seen, unseen

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: String(localized: "All", bundle: .app)
        case .seen: String(localized: "Logged", bundle: .app)
        case .unseen: String(localized: "Not logged", bundle: .app)
        }
    }
}

/// What the Guide list is narrowed to. `order` and `family` are the Latin names the server sends in its facets.
struct SpeciesFilter: Equatable, Sendable {
    /// Several values of one kind mean "any of them". Kept sorted, so the same choice always gives the same request.
    var orders: [String] = []
    var families: [String] = []
    var seen = SeenFilter.all

    var isActive: Bool { !orders.isEmpty || !families.isEmpty || seen != .all }

    var queryItems: [URLQueryItem] {
        var items = orders.map { URLQueryItem(name: "order", value: $0) }
        items += families.map { URLQueryItem(name: "family", value: $0) }
        if seen != .all { items.append(URLQueryItem(name: "seen", value: seen.rawValue)) }
        return items
    }

    mutating func toggleOrder(_ value: String) { Self.toggle(value, in: &orders) }
    mutating func toggleFamily(_ value: String) { Self.toggle(value, in: &families) }

    private static func toggle(_ value: String, in values: inout [String]) {
        if let index = values.firstIndex(of: value) { values.remove(at: index) } else { values = (values + [value]).sorted() }
    }
}

/// The orders and families the filter menus offer, with names in the app's language and how many species each has.
struct SpeciesFacets: Decodable, Sendable, Equatable {
    struct Order: Decodable, Sendable, Equatable, Identifiable {
        let value: String
        let name: String
        let count: Int
        var id: String { value }
    }

    struct Family: Decodable, Sendable, Equatable, Identifiable {
        let value: String
        let order: String?
        let name: String
        let count: Int
        var id: String { value }
    }

    var orders: [Order]
    var families: [Family]

    static let empty = SpeciesFacets(orders: [], families: [])
}

enum SpeciesAPI {
    /// The seen filter is about the signed-in user, so only a request that uses it carries the token.
    static func list(
        search: String, page: Int, size: Int = 30, sort: SpeciesSort = .commonAscending, language: String,
        filter: SpeciesFilter = SpeciesFilter()
    ) -> Endpoint<Page<Species>> {
        var query = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "size", value: String(size)),
            URLQueryItem(name: "sort", value: sort.parameter(language: language)),
        ]
        let search = search.trimmingCharacters(in: .whitespaces)
        if !search.isEmpty { query.append(URLQueryItem(name: "search", value: search)) }
        query.append(contentsOf: filter.queryItems)
        return Endpoint(.get, "species", query: query, requiresAuth: filter.seen != .all)
    }

    static func facets(search: String, filter: SpeciesFilter) -> Endpoint<SpeciesFacets> {
        var query: [URLQueryItem] = []
        let search = search.trimmingCharacters(in: .whitespaces)
        if !search.isEmpty { query.append(URLQueryItem(name: "search", value: search)) }
        query.append(contentsOf: filter.queryItems)
        return Endpoint(.get, "species/facets", query: query, requiresAuth: filter.seen != .all)
    }

    static func species(id: UUID) -> Endpoint<Species> {
        Endpoint(.get, "species/\(id.uuidString.lowercased())", requiresAuth: false)
    }

    static func sounds(id: UUID) -> Endpoint<[SpeciesRecording]> {
        Endpoint(.get, "species/\(id.uuidString.lowercased())/sound", requiresAuth: false)
    }
}

enum UploadAPI {
    struct UploadResponse: Decodable, Sendable {
        let url: String
        let thumbnailUrl: String?
    }

    static func photo(jpeg: Data) -> Endpoint<UploadResponse> {
        let boundary = "wingmark-\(UUID().uuidString)"
        var body = Data()
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"file\"; filename=\"photo.jpg\"\r\n".utf8))
        body.append(Data("Content-Type: image/jpeg\r\n\r\n".utf8))
        body.append(jpeg)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        return Endpoint(.post, "uploads/photo", body: .raw(body, contentType: "multipart/form-data; boundary=\(boundary)"))
    }
}
