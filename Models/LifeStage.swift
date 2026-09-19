import Foundation

/// Mirrors wingmark-backend's LifeStage enum.
enum LifeStage: String, Codable, CaseIterable, Identifiable {
    case baby = "BABY"
    case adult = "ADULT"
    case unknown = "UNKNOWN"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .adult: "Adult"
        case .baby: "Baby"
        case .unknown: "Unknown"
        }
    }
}
