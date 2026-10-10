import Foundation
import Observation
import SwiftUI

enum BadgeTier: String, Codable, Sendable, CaseIterable {
    case bronze = "BRONZE", silver = "SILVER", gold = "GOLD", diamond = "DIAMOND"

    init(from decoder: any Decoder) throws {
        self = BadgeTier(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .bronze
    }

    var title: String {
        switch self {
        case .bronze: String(localized: "Bronze", bundle: .app)
        case .silver: String(localized: "Silver", bundle: .app)
        case .gold: String(localized: "Gold", bundle: .app)
        case .diamond: String(localized: "Diamond", bundle: .app)
        }
    }

    var color: Color {
        switch self {
        case .bronze: Color(red: 205 / 255, green: 127 / 255, blue: 50 / 255)   // #CD7F32
        case .silver: Color(red: 192 / 255, green: 192 / 255, blue: 192 / 255)  // #C0C0C0
        case .gold: Color(red: 1, green: 215 / 255, blue: 0)                    // #FFD700
        case .diamond: Color(red: 185 / 255, green: 242 / 255, blue: 1)         // #B9F2FF, frosted blue
        }
    }

    /// The tier color darkened, for rings and progress bars, which would otherwise vanish on a light background.
    var edgeColor: Color { color.mix(with: .black, by: 0.3) }
}

struct CatalogBadge: Decodable, Sendable, Identifiable {
    let id: UUID
    let name: LocalizedText
    let description: LocalizedText?
    let icon: String?
    let criteriaValue: Int?
    let tier: BadgeTier?
}

/// An entry of `GET /badges/user/{id}`. A locked secret badge has only `badgeId`, `secret`, `earned` and `tier`; everything
/// else is null, so every other field is optional.
struct UserBadge: Decodable, Sendable {
    let badgeId: UUID
    var secret: Bool?
    let badgeName: String?
    let badgeIcon: String?
    var badgeDescription: String?
    var tier: BadgeTier?
    let earned: Bool
    let earnedAt: Date?
    let progress: Int?
    let targetValue: Int?
}

/// How secret badges are treated, in one place so the defaults are easy to change.
enum BadgePolicy {
    /// "3 of 22 earned" counts locked secrets in the total.
    static let hiddenSecretsCountInTotal = true
    /// Locked secrets sit after the regular badges; once earned they move up with the earned ones.
    static let lockedSecretsLast = true
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
    var isSecret = false

    /// A secret badge that hasn't been earned: it has no name, description, icon or progress to show.
    var isLockedSecret: Bool { isSecret && !earned }

    var fraction: Double {
        guard target > 0 else { return earned ? 1 : 0 }
        return min(Double(progress) / Double(target), 1)
    }

    /// The user's badges, earned ones first, each group in the order the server sent them (its `displayOrder`). Text, icon
    /// and tier come from the user's list (already in the app's language); the catalog fills in anything missing and gives
    /// the names in every language for the widget. Secret badges aren't in the catalog. A catalog badge missing from the
    /// user's list isn't shown: the server leaves out badges that don't apply to this user, such as the favorite-species
    /// badges for someone with no favorite species.
    static func merge(catalog: [CatalogBadge], user: [UserBadge]) -> [BadgeProgress] {
        let catalogById = Dictionary(catalog.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var seen = Set<UUID>()
        let inServerOrder: [BadgeProgress] = user.compactMap { mine in
            guard seen.insert(mine.badgeId).inserted else { return nil }
            let badge = catalogById[mine.badgeId]
            return BadgeProgress(
                id: mine.badgeId,
                name: mine.badgeName ?? badge?.name.resolved() ?? "",
                description: mine.badgeDescription ?? badge?.description?.resolved(),
                icon: mine.badgeIcon ?? badge?.icon,
                tier: mine.tier ?? badge?.tier ?? .bronze,
                earned: mine.earned,
                earnedAt: mine.earnedAt,
                progress: mine.progress ?? 0,
                target: mine.targetValue ?? 0,
                names: badge?.name.values ?? [:],
                isSecret: mine.secret ?? false
            )
        }
        // A stable split: earned badges move up without being reordered among themselves or the rest.
        let earned = inServerOrder.filter(\.earned)
        let locked = inServerOrder.filter { !$0.earned }
        guard BadgePolicy.lockedSecretsLast else { return earned + locked }
        return earned + locked.filter { !$0.isLockedSecret } + locked.filter(\.isLockedSecret)
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

    /// The "y" in "x of y earned".
    var totalCount: Int { BadgePolicy.hiddenSecretsCountInTotal ? badges.count : badges.filter { !$0.isLockedSecret }.count }

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
