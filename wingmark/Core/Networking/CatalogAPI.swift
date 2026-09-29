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

enum SpeciesAPI {
    static func list(search: String, page: Int, size: Int = 30, language: String) -> Endpoint<Page<Species>> {
        var query = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "size", value: String(size)),
            URLQueryItem(name: "sort", value: "commonName.\(language),asc"),
        ]
        let search = search.trimmingCharacters(in: .whitespaces)
        if !search.isEmpty { query.append(URLQueryItem(name: "search", value: search)) }
        return Endpoint(.get, "species", query: query, requiresAuth: false)
    }

    static func species(id: UUID) -> Endpoint<Species> {
        Endpoint(.get, "species/\(id.uuidString.lowercased())", requiresAuth: false)
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
