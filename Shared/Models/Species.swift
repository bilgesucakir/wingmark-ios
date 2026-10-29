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

    func resolved(_ language: String = AppLanguage.current.code) -> String? {
        let value = values[language] ?? values["en"] ?? values.values.first
        return value?.isEmpty == false ? value : values["en"]
    }
}

struct SpeciesImage: Codable, Sendable, Hashable, Identifiable {
    let id: UUID
    let lifeStage: String?
    let gender: String?
    let imageUrl: String
    /// ~400 px version for lists; null for external photos.
    var thumbnailUrl: String?
    let caption: String?
    /// Null for Wingmark's own uploads; set for openly licensed photos, which must show `attribution`.
    var licenseCode: String?
    var attribution: String?
    var sourceUrl: String?
}

extension SpeciesImage {
    /// One short line for the photo credit, or nil for Wingmark's own uploads.
    /// Wikimedia attributions can start with the file name ("Bird_1.jpg: Jane Doe / ...") or be only a file name; neither is shown.
    var creditText: String? {
        guard let code = licenseCode else { return nil }
        var author = attribution?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = author?.range(of: #"^[^:/]*\.(jpe?g|png|gif|webp|tiff?|svg)\s*:\s*"#, options: [.regularExpression, .caseInsensitive]) {
            author?.removeSubrange(range)
        }
        if let text = author, text.range(of: #"^\S+\.(jpe?g|png|gif|webp|tiff?|svg)$"#, options: [.regularExpression, .caseInsensitive]) != nil {
            author = nil
        }
        let license = Self.displayLicense(code)
        guard let author, !author.isEmpty else { return license }
        let credit = author.localizedCaseInsensitiveContains(license) ? author : "\(author) · \(license)"
        return Self.unbreakingLicense(in: credit)
    }

    /// Keeps "CC BY-SA 4.0" on one line instead of wrapping at the hyphen or the space.
    private static func unbreakingLicense(in text: String) -> String {
        guard let range = text.range(of: #"CC [A-Z]+(-[A-Z]+)* \d(\.\d)?"#, options: .regularExpression) else { return text }
        let glued = text[range].replacingOccurrences(of: " ", with: "\u{00A0}").replacingOccurrences(of: "-", with: "\u{2011}")
        return text.replacingCharacters(in: range, with: glued)
    }

    /// "cc-by-sa-4.0" becomes "CC BY-SA 4.0"; anything else is shown as given.
    static func displayLicense(_ code: String) -> String {
        let parts = code.split(separator: "-").map(String.init)
        guard parts.count >= 3, parts[0].lowercased() == "cc", let version = parts.last, version.first?.isNumber == true else { return code }
        return "CC " + parts.dropFirst().dropLast().joined(separator: "-").uppercased() + " " + version
    }
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
