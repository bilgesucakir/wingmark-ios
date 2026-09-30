import Foundation

enum LifeStage: String, Codable, Sendable, CaseIterable, Identifiable {
    case adult = "ADULT", baby = "BABY", unknown = "UNKNOWN"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .adult: String(localized: "Adult", bundle: .app)
        case .baby: String(localized: "Juvenile", bundle: .app)
        case .unknown: String(localized: "Unknown", bundle: .app)
        }
    }
}

enum Gender: String, Codable, Sendable, CaseIterable, Identifiable {
    case male = "MALE", female = "FEMALE", unknown = "UNKNOWN"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .male: String(localized: "Male", bundle: .app)
        case .female: String(localized: "Female", bundle: .app)
        case .unknown: String(localized: "Unknown", bundle: .app)
        }
    }
}

enum SpeciesStatus: String, Codable, Sendable, CaseIterable, Identifiable {
    case guess = "GUESS", confident = "CONFIDENT"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .guess: String(localized: "Guess", bundle: .app)
        case .confident: String(localized: "Confident", bundle: .app)
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
    /// Older records may lack coordinates; they stay in the diary but get no map pin.
    let hasLocation: Bool

    enum CodingKeys: String, CodingKey {
        case id, userId, speciesId, speciesCommonName, speciesStatus, pet, customName, lifeStage, gender
        case photoUrl, note, latitude, longitude, locationName, observedAt, createdAt
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        userId = try c.decode(UUID.self, forKey: .userId)
        speciesId = try c.decodeIfPresent(UUID.self, forKey: .speciesId)
        speciesCommonName = try c.decodeIfPresent(String.self, forKey: .speciesCommonName)
        speciesStatus = try? c.decodeIfPresent(SpeciesStatus.self, forKey: .speciesStatus)
        pet = (try? c.decodeIfPresent(Bool.self, forKey: .pet)) ?? false
        customName = try c.decodeIfPresent(String.self, forKey: .customName)
        lifeStage = (try? c.decodeIfPresent(LifeStage.self, forKey: .lifeStage)) ?? .unknown
        gender = (try? c.decodeIfPresent(Gender.self, forKey: .gender)) ?? .unknown
        photoUrl = try c.decodeIfPresent(String.self, forKey: .photoUrl)
        note = try c.decodeIfPresent(String.self, forKey: .note)
        let latitude = try c.decodeIfPresent(Double.self, forKey: .latitude)
        let longitude = try c.decodeIfPresent(Double.self, forKey: .longitude)
        hasLocation = latitude != nil && longitude != nil
        self.latitude = latitude ?? 0
        self.longitude = longitude ?? 0
        locationName = try c.decodeIfPresent(String.self, forKey: .locationName)
        let observed = try c.decodeIfPresent(Date.self, forKey: .observedAt)
        let created = try c.decodeIfPresent(Date.self, forKey: .createdAt)
        observedAt = observed ?? created ?? .distantPast
        createdAt = created ?? observed ?? .distantPast
    }

    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(userId, forKey: .userId)
        try c.encodeIfPresent(speciesId, forKey: .speciesId)
        try c.encodeIfPresent(speciesCommonName, forKey: .speciesCommonName)
        try c.encodeIfPresent(speciesStatus, forKey: .speciesStatus)
        try c.encode(pet, forKey: .pet)
        try c.encodeIfPresent(customName, forKey: .customName)
        try c.encode(lifeStage, forKey: .lifeStage)
        try c.encode(gender, forKey: .gender)
        try c.encodeIfPresent(photoUrl, forKey: .photoUrl)
        try c.encodeIfPresent(note, forKey: .note)
        if hasLocation {
            try c.encode(latitude, forKey: .latitude)
            try c.encode(longitude, forKey: .longitude)
        }
        try c.encodeIfPresent(locationName, forKey: .locationName)
        try c.encode(observedAt, forKey: .observedAt)
        try c.encode(createdAt, forKey: .createdAt)
    }

    var displayName: String {
        if let name = customName?.trimmingCharacters(in: .whitespaces), !name.isEmpty { return name }
        return speciesCommonName ?? String(localized: "Unidentified bird", bundle: .app)
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
            case .any: String(localized: "All", bundle: .app)
            case .identified: String(localized: "Identified", bundle: .app)
            case .unidentified: String(localized: "Unidentified", bundle: .app)
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
