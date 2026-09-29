import Foundation

/// A `{en, tr}` map from the catalog endpoints.
struct LocalizedText: Codable, Sendable, Hashable {
    let values: [String: String]

    init(_ values: [String: String]) {
        self.values = values
    }

    init(from decoder: any Decoder) throws {
        values = (try? decoder.singleValueContainer().decode([String: String].self)) ?? [:]
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(values)
    }

    func resolved(_ language: String = AppLanguage.current.resolvedCode) -> String? {
        let value = values[language] ?? values["en"] ?? values.values.first
        return value?.isEmpty == false ? value : values["en"]
    }
}

struct SpeciesImage: Codable, Sendable, Hashable, Identifiable {
    let id: UUID
    let lifeStage: String?
    let gender: String?
    let imageUrl: String
    let caption: String?
}

struct Species: Codable, Sendable, Hashable, Identifiable {
    let id: UUID
    let commonName: LocalizedText
    let scientificName: String?
    let family: String?
    let order: String?
    let description: LocalizedText?
    let lifespan: LocalizedText?
    let diet: LocalizedText?
    let habitat: LocalizedText?
    let sizeDescription: LocalizedText?
    let conservationStatus: LocalizedText?
    let nativeRange: LocalizedText?
    let images: [SpeciesImage]?

    var name: String { commonName.resolved() ?? scientificName ?? "" }
}

struct Page<Item: Decodable>: Decodable {
    struct Info: Decodable {
        let size: Int
        let number: Int
        let totalElements: Int
        let totalPages: Int
    }

    let content: [Item]
    let page: Info

    var hasMore: Bool { page.number + 1 < page.totalPages }
}
