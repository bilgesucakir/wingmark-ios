import Foundation

/// Where a widget tap or the Home Screen quick action sends the person.
nonisolated enum AppLink: Equatable, Sendable {
    case logSighting
    case badges
    case guide
    case sighting(UUID)

    static let scheme = "wingmark"

    init?(url: URL) {
        guard url.scheme == Self.scheme else { return nil }
        switch (url.host(), url.pathComponents.dropFirst().first) {
        case ("log", nil): self = .logSighting
        case ("badges", nil): self = .badges
        case ("guide", nil): self = .guide
        case ("sighting", let id?): guard let uuid = UUID(uuidString: id) else { return nil }
            self = .sighting(uuid)
        default: return nil
        }
    }

    var url: URL {
        switch self {
        case .logSighting: URL(string: "\(Self.scheme)://log")!
        case .badges: URL(string: "\(Self.scheme)://badges")!
        case .guide: URL(string: "\(Self.scheme)://guide")!
        case .sighting(let id): URL(string: "\(Self.scheme)://sighting/\(id.uuidString.lowercased())")!
        }
    }
}
