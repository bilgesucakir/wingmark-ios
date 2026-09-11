import Foundation

enum LifeStage: String, Codable, CaseIterable, Identifiable {
    case adult
    case baby

    var id: String { rawValue }

    var label: String {
        switch self {
        case .adult: "Adult"
        case .baby: "Baby"
        }
    }
}
