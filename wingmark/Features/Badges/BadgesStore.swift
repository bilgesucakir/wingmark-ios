import Foundation
import Observation
import SwiftUI

enum BadgeTier: String, Codable, Sendable, CaseIterable {
    case bronze = "BRONZE", silver = "SILVER", gold = "GOLD"

    init(from decoder: any Decoder) throws {
        self = BadgeTier(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .bronze
    }

    var title: String {
        switch self {
        case .bronze: String(localized: "Bronze", bundle: .app)
        case .silver: String(localized: "Silver", bundle: .app)
        case .gold: String(localized: "Gold", bundle: .app)
        }
    }

    var color: Color {
        switch self {
        case .bronze: Color(red: 0.80, green: 0.50, blue: 0.20)
        case .silver: Color(red: 0.62, green: 0.65, blue: 0.70)
        case .gold: Color(red: 0.95, green: 0.72, blue: 0.10)
        }
    }
}

struct CatalogBadge: Decodable, Sendable, Identifiable {
    let id: UUID
    let name: LocalizedText
    let description: LocalizedText?
    let icon: String?
    let criteriaValue: Int?
    let tier: BadgeTier?
}

struct UserBadge: Decodable, Sendable {
    let badgeId: UUID
    let badgeName: String?
    let badgeIcon: String?
    let earned: Bool
    let earnedAt: Date?
    let progress: Int
    let targetValue: Int
}

struct BadgeProgress: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let description: String?
    let icon: String?
    let tier: BadgeTier
    let earned: Bool
    let earnedAt: Date?
    let progress: Int
    let target: Int
    var names: [String: String] = [:]

    var fraction: Double {
        guard target > 0 else { return earned ? 1 : 0 }
        return min(Double(progress) / Double(target), 1)
    }

    /// The user's badges, earned ones first, each group in the order the server sent them (its `displayOrder`), with
    /// text and tier from the catalog. A catalog badge missing from the user's list isn't shown: the server leaves out
    /// badges that don't apply to this user, such as the favorite-species badges for someone with no favorite species.
    static func merge(catalog: [CatalogBadge], user: [UserBadge]) -> [BadgeProgress] {
        let catalogById = Dictionary(catalog.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var seen = Set<UUID>()
        let inServerOrder: [BadgeProgress] = user.compactMap { mine in
            guard seen.insert(mine.badgeId).inserted else { return nil }
            let badge = catalogById[mine.badgeId]
            return BadgeProgress(
                id: mine.badgeId,
                name: badge?.name.resolved() ?? mine.badgeName ?? "",
                description: badge?.description?.resolved(),
                icon: badge?.icon ?? mine.badgeIcon,
                tier: badge?.tier ?? .bronze,
                earned: mine.earned,
                earnedAt: mine.earnedAt,
                progress: mine.progress,
                target: mine.targetValue,
                names: badge?.name.values ?? [:]
            )
        }
        // A stable split: earned badges move up without being reordered among themselves or the rest.
        return inServerOrder.filter(\.earned) + inServerOrder.filter { !$0.earned }
    }
}

enum BadgeAPI {
    static func catalog() -> Endpoint<[CatalogBadge]> {
        Endpoint(.get, "badges/catalog", requiresAuth: false)
    }

    static func userBadges(userId: UUID) -> Endpoint<[UserBadge]> {
        Endpoint(.get, "badges/user/\(userId.uuidString.lowercased())")
    }
}

@Observable
final class BadgesStore {
    private(set) var badges: [BadgeProgress] = []
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    private(set) var loadError: APIError?
    /// Badges earned since the previous load, for the celebration.
    var newlyEarned: [BadgeProgress] = []

    private let session: AuthSession

    init(session: AuthSession) {
        self.session = session
    }

    var earnedCount: Int { badges.filter(\.earned).count }

    func load() async {
        guard let userId = session.userId else { return }
        isLoading = true
        defer { isLoading = false }
        do throws(APIError) {
            let catalog = try await session.client.send(BadgeAPI.catalog())
            let user = try await session.client.send(BadgeAPI.userBadges(userId: userId))
            let merged = BadgeProgress.merge(catalog: catalog, user: user)
            if hasLoaded {
                let previouslyEarned = Set(badges.filter(\.earned).map(\.id))
                let fresh = merged.filter { $0.earned && !previouslyEarned.contains($0.id) }
                if !fresh.isEmpty { newlyEarned.append(contentsOf: fresh) }
            }
            badges = merged
            loadError = nil
            hasLoaded = true
        } catch {
            guard !error.isCancellation else { return }
            loadError = error
        }
    }
}
