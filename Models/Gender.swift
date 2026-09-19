import Foundation

/// Mirrors wingmark-backend's Gender enum.
enum Gender: String, Codable, CaseIterable, Identifiable {
    case male = "MALE"
    case female = "FEMALE"
    case unknown = "UNKNOWN"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .male: "Male"
        case .female: "Female"
        case .unknown: "Unknown"
        }
    }
}
