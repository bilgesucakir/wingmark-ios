import Foundation

/// Mirrors wingmark-backend's SpeciesStatus enum. Only meaningful when a
/// sighting's species is actually set — nil when the species itself is unknown.
enum SpeciesStatus: String, Codable, CaseIterable, Identifiable {
    case guess = "GUESS"
    case confident = "CONFIDENT"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .guess: "Just a guess"
        case .confident: "Confident"
        }
    }
}
