import Foundation

/// Mirrors wingmark-backend's Visibility enum.
enum SightingVisibility: String, Codable, CaseIterable, Identifiable {
    case `private` = "PRIVATE"
    case `public` = "PUBLIC"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .private: "Private"
        case .public: "Public"
        }
    }
}
