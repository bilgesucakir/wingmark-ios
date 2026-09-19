import Foundation

/// Mirrors wingmark-backend's BadgeCriteriaType enum. The two radius-based
/// types (SPECIES_IN_RADIUS, SIGHTINGS_IN_RADIUS) and SPECIES_LOGS need a
/// real backend query (geo clustering / a specific species id) to mean
/// anything, so they're left out of the mock catalog below rather than faked.
enum BadgeCriteriaType: String {
    case totalLogs = "TOTAL_LOGS"
    case uniqueSpecies = "UNIQUE_SPECIES"
    case babyLogs = "BABY_LOGS"
    case unknownSpeciesLogs = "UNKNOWN_SPECIES_LOGS"
    case petLogs = "PET_LOGS"
}

/// Mirrors wingmark-backend's BadgeTier enum.
enum BadgeTier: String {
    case bronze = "BRONZE"
    case silver = "SILVER"
    case gold = "GOLD"

    var label: String {
        switch self {
        case .bronze: "Bronze"
        case .silver: "Silver"
        case .gold: "Gold"
        }
    }
}

/// Stands in for wingmark-backend's `/api/badges/catalog` response until the
/// real endpoint is wired up.
struct Badge: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let criteriaType: BadgeCriteriaType
    let criteriaValue: Int
    let tier: BadgeTier

    static let mockCatalog: [Badge] = [
        Badge(name: "First Sighting", icon: "trophy.fill", criteriaType: .totalLogs, criteriaValue: 1, tier: .bronze),
        Badge(name: "Ten Sightings", icon: "trophy.fill", criteriaType: .totalLogs, criteriaValue: 10, tier: .silver),
        Badge(name: "Fifty Sightings", icon: "trophy.fill", criteriaType: .totalLogs, criteriaValue: 50, tier: .gold),
        Badge(name: "Five Species", icon: "bird.fill", criteriaType: .uniqueSpecies, criteriaValue: 5, tier: .bronze),
        Badge(name: "Twenty Species", icon: "bird.fill", criteriaType: .uniqueSpecies, criteriaValue: 20, tier: .gold),
        Badge(name: "Baby Watcher", icon: "leaf.fill", criteriaType: .babyLogs, criteriaValue: 5, tier: .silver),
        Badge(name: "Mystery Bird", icon: "questionmark.circle.fill", criteriaType: .unknownSpeciesLogs, criteriaValue: 3, tier: .bronze),
        Badge(name: "Pet Lover", icon: "heart.fill", criteriaType: .petLogs, criteriaValue: 5, tier: .bronze),
    ]
}

struct BadgeProgress {
    let badge: Badge
    let progress: Int

    var isEarned: Bool { progress >= badge.criteriaValue }

    static func compute(for sightings: [BirdSighting]) -> [BadgeProgress] {
        Badge.mockCatalog.map { badge in
            let progress: Int
            switch badge.criteriaType {
            case .totalLogs:
                progress = sightings.count
            case .uniqueSpecies:
                progress = Set(sightings.compactMap { $0.species?.commonName }).count
            case .babyLogs:
                progress = sightings.filter { $0.lifeStage == .baby }.count
            case .unknownSpeciesLogs:
                progress = sightings.filter { $0.species == nil }.count
            case .petLogs:
                progress = sightings.filter { $0.isPet }.count
            }
            return BadgeProgress(badge: badge, progress: min(progress, badge.criteriaValue))
        }
    }
}
