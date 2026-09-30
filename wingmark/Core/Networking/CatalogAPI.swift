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

enum SpeciesAPI {
    static func list(
        search: String, page: Int, size: Int = 30, sort: SpeciesSort = .commonAscending, language: String
    ) -> Endpoint<Page<Species>> {
        var query = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "size", value: String(size)),
            URLQueryItem(name: "sort", value: sort.parameter(language: language)),
        ]
        let search = search.trimmingCharacters(in: .whitespaces)
        if !search.isEmpty { query.append(URLQueryItem(name: "search", value: search)) }
        return Endpoint(.get, "species", query: query, requiresAuth: false)
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
