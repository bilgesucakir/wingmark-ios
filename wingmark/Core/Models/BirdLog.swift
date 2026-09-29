import Foundation

enum LifeStage: String, Codable, Sendable, CaseIterable, Identifiable {
    case adult = "ADULT", baby = "BABY", unknown = "UNKNOWN"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .adult: String(localized: "Adult")
        case .baby: String(localized: "Juvenile")
        case .unknown: String(localized: "Unknown")
        }
    }
}

enum Gender: String, Codable, Sendable, CaseIterable, Identifiable {
    case male = "MALE", female = "FEMALE", unknown = "UNKNOWN"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .male: String(localized: "Male")
        case .female: String(localized: "Female")
        case .unknown: String(localized: "Unknown")
        }
    }
}

enum SpeciesStatus: String, Codable, Sendable, CaseIterable, Identifiable {
    case guess = "GUESS", confident = "CONFIDENT"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .guess: String(localized: "Guess")
        case .confident: String(localized: "Confident")
        }
    }
}

struct BirdLog: Codable, Sendable, Equatable, Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    var speciesId: UUID?
    var speciesCommonName: String?
    var speciesStatus: SpeciesStatus?
    var pet: Bool
    var customName: String?
    var lifeStage: LifeStage
    var gender: Gender
    var photoUrl: String?
    var note: String?
    var latitude: Double
    var longitude: Double
    var locationName: String?
    var observedAt: Date
    let createdAt: Date

    var displayName: String {
        if let name = customName?.trimmingCharacters(in: .whitespaces), !name.isEmpty { return name }
        return speciesCommonName ?? String(localized: "Unidentified bird")
    }
}

/// Body for POST and PUT `/bird-logs`. A nil `observedAt` is omitted, which keeps the stored value on PUT.
struct BirdLogInput: Encodable, Sendable, Equatable {
    var speciesId: UUID?
    var speciesStatus: SpeciesStatus?
    var pet = false
    var customName: String?
    var lifeStage: LifeStage = .unknown
    var gender: Gender = .unknown
    var photoUrl: String?
    var note: String?
    var latitude: Double
    var longitude: Double
    var locationName: String?
    var observedAt: Date?

    enum CodingKeys: String, CodingKey {
        case speciesId, speciesStatus, pet, customName, lifeStage, gender, photoUrl, note
        case latitude, longitude, locationName, observedAt
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(speciesId, forKey: .speciesId)
        try container.encode(speciesId == nil ? nil : speciesStatus, forKey: .speciesStatus)
        try container.encode(pet, forKey: .pet)
        try container.encode(customName, forKey: .customName)
        try container.encode(lifeStage, forKey: .lifeStage)
        try container.encode(gender, forKey: .gender)
        try container.encode(photoUrl, forKey: .photoUrl)
        try container.encode(note, forKey: .note)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
        try container.encode(locationName, forKey: .locationName)
        try container.encodeIfPresent(observedAt, forKey: .observedAt)
    }
}

struct DiaryFilter: Equatable, Sendable {
    enum Identification: String, CaseIterable, Identifiable, Sendable {
        case any, identified, unidentified
        var id: String { rawValue }

        var title: String {
            switch self {
            case .any: String(localized: "All")
            case .identified: String(localized: "Identified")
            case .unidentified: String(localized: "Unidentified")
            }
        }
    }

    var identification: Identification = .any
    var gender: Gender?
    var lifeStage: LifeStage?
    var newestFirst = true

    var isActive: Bool { identification != .any || gender != nil || lifeStage != nil }

    var queryItems: [URLQueryItem] {
        var items: [URLQueryItem] = []
        switch identification {
        case .any: break
        case .identified: items.append(URLQueryItem(name: "hasSpecies", value: "true"))
        case .unidentified: items.append(URLQueryItem(name: "hasSpecies", value: "false"))
        }
        if let gender { items.append(URLQueryItem(name: "gender", value: gender.rawValue)) }
        if let lifeStage { items.append(URLQueryItem(name: "lifeStage", value: lifeStage.rawValue)) }
        return items
    }
}
