import Foundation

/// One Guide species picked for the day, with what a widget shows. All of it is public Guide data.
nonisolated struct BirdOfTheDay: Codable, Equatable, Sendable {
    /// Missing in birds saved by older builds; the widget then opens the Guide.
    var id: UUID?
    var name: String
    var scientificName: String?
    var summary: String?
    var photoURL: URL?
    /// Set for openly licensed photos, which must be credited.
    var credit: String?
}

nonisolated enum BirdOfTheDayFetcher {
    static let baseURL = URL(string: "https://wingmark-backend.onrender.com/api")!

    private struct PageDTO: Decodable {
        struct Info: Decodable { let totalElements: Int }
        let content: [SpeciesDTO]
        let page: Info
    }

    private struct SpeciesDTO: Decodable {
        struct Image: Decodable {
            let imageUrl: String
            let licenseCode: String?
            let attribution: String?
        }

        let id: UUID?
        let commonName: [String: String]?
        let scientificName: String?
        let description: [String: String]?
        let images: [Image]?
    }

    /// The same bird all day for everyone: a fixed stride through the alphabetical list, one step per day.
    static func index(on date: Date, total: Int, calendar: Calendar = Calendar(identifier: .gregorian)) -> Int {
        guard total > 0 else { return 0 }
        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        return (day * 7919) % total
    }

    static func fetch(
        on date: Date, language: String, load: (URL) async throws -> Data
    ) async -> BirdOfTheDay? {
        guard let first = try? await page(0, load: load), first.page.totalElements > 0 else { return nil }
        let total = first.page.totalElements
        let start = index(on: date, total: total)
        // A species without a photo isn't a good "bird of the day", so try the next few.
        for step in 0..<5 {
            let position = (start + step) % total
            let dto = position == 0 ? first.content.first : (try? await page(position, load: load))?.content.first
            if let dto, let bird = bird(from: dto, language: language) { return bird }
        }
        return nil
    }

    private static func page(_ number: Int, load: (URL) async throws -> Data) async throws -> PageDTO {
        var components = URLComponents(url: baseURL.appending(path: "species"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "page", value: String(number)),
            URLQueryItem(name: "size", value: "1"),
            URLQueryItem(name: "sort", value: "commonName.en,asc"),
        ]
        return try JSONDecoder().decode(PageDTO.self, from: try await load(components.url!))
    }

    private static func bird(from dto: SpeciesDTO, language: String) -> BirdOfTheDay? {
        guard let image = dto.images?.first,
              let photo = URL(string: image.imageUrl, relativeTo: URL(string: "https://wingmark-backend.onrender.com"))?.absoluteURL
        else { return nil }
        func pick(_ values: [String: String]?) -> String? {
            let text = values?[language] ?? values?["en"] ?? values?.values.first
            return text.flatMap { $0.isEmpty ? nil : $0 }
        }
        guard let name = pick(dto.commonName) ?? dto.scientificName else { return nil }
        let credit = image.licenseCode.map { license in image.attribution.map { "\($0) · \(license)" } ?? license }
        return BirdOfTheDay(id: dto.id, name: name, scientificName: dto.scientificName, summary: pick(dto.description), photoURL: photo, credit: credit)
    }
}
