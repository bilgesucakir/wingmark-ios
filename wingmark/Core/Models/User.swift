import Foundation

enum Role: String, Codable, Sendable {
    case user = "USER"
    case admin = "ADMIN"

    init(from decoder: any Decoder) throws {
        self = Role(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .user
    }
}

enum UnitPreference: String, Codable, Sendable, CaseIterable {
    case metric = "METRIC"
    case imperial = "IMPERIAL"
}

struct UserProfile: Codable, Sendable, Equatable, Identifiable {
    let id: UUID
    let email: String
    let username: String
    var firstName: String?
    var lastName: String?
    /// nil, a preset key (`avatar-3`) or a relative `/uploads/<file>` URL.
    var profilePicture: String?
    var favoriteSpeciesId: UUID?
    var favoriteSpeciesName: String?
    let role: Role
    let emailVerified: Bool
    /// Accounts created before the backend's auditing fix have no creation date.
    let createdAt: Date?
    /// When the in-app walkthrough was closed on any device; nil until then.
    var walkthroughSeenAt: Date?

    var displayName: String {
        let full = [firstName, lastName].compactMap { $0?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return full.isEmpty ? username : full
    }
}

struct UserSettings: Codable, Sendable, Equatable {
    var unitPreference: UnitPreference
    var locale: String?
}

struct RegisterResponse: Decodable, Sendable, Equatable {
    let userId: UUID
    let email: String
    let username: String
    let emailVerified: Bool
}
