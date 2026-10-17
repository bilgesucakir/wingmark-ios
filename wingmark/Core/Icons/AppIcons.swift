import Foundation
import Observation
import UIKit

/// One icon from `GET /api/app-icons`. `iconId` is the name of the bundled `.icon` package.
struct AppIconOption: Decodable, Sendable, Identifiable, Equatable {
    let iconId: String
    let nameEn: String
    let nameTr: String

    var id: String { iconId }

    func name(language: AppLanguage = .current) -> String {
        language == .turkish ? nameTr : nameEn
    }
}

enum AppIconAPI {
    static func list() -> Endpoint<[AppIconOption]> {
        Endpoint(.get, "app-icons")
    }
}

/// The alternate icons this build contains, read from the Info.plist the asset compiler writes.
enum BundledAppIcons {
    static func ids(in info: [String: Any]? = Bundle.main.infoDictionary) -> Set<String> {
        let icons = info?["CFBundleIcons"] as? [String: Any]
        let alternates = icons?["CFBundleAlternateIcons"] as? [String: Any]
        return Set(alternates?.keys.map { $0 } ?? [])
    }
}

struct AppIconSwitcher {
    var current: () -> String?
    var set: (String?) async throws -> Void

    static let system = AppIconSwitcher(
        current: { UIApplication.shared.alternateIconName },
        set: { try await UIApplication.shared.setAlternateIconName($0) }
    )
}

/// What the picker lists: the default icon, then the backend's icons that this build contains.
@MainActor
@Observable
final class AppIconPicker {
    struct Row: Identifiable, Equatable {
        enum Kind: Equatable { case standard, listed(AppIconOption), unlisted }
        let iconName: String?
        let kind: Kind
        var id: String { iconName ?? "" }
    }

    private(set) var options: [AppIconOption] = []
    private(set) var current: String?
    private(set) var isLoading = false
    var errorMessage: String?
    var pending: Row?

    private let bundled: Set<String>
    private let switcher: AppIconSwitcher

    init(bundled: Set<String> = BundledAppIcons.ids(), switcher: AppIconSwitcher = .system) {
        self.bundled = bundled
        self.switcher = switcher
        current = switcher.current()
    }

    /// An icon the backend no longer lists stays selected and working; the default stays one tap away.
    var rows: [Row] {
        var rows = [Row(iconName: nil, kind: .standard)]
        rows += options.map { Row(iconName: $0.iconId, kind: .listed($0)) }
        if let current, !options.contains(where: { $0.iconId == current }) {
            rows.append(Row(iconName: current, kind: .unlisted))
        }
        return rows
    }

    func isCurrent(_ row: Row) -> Bool { row.iconName == current }

    func load(using client: APIClient) async {
        isLoading = true
        defer { isLoading = false }
        let listed = (try? await client.send(AppIconAPI.list())) ?? []
        options = Self.available(listed, bundled: bundled)
        current = switcher.current()
    }

    static func available(_ listed: [AppIconOption], bundled: Set<String>) -> [AppIconOption] {
        var seen = Set<String>()
        return listed.filter { bundled.contains($0.iconId) && seen.insert($0.iconId).inserted }
    }

    func choose(_ row: Row) {
        guard !isCurrent(row) else { return }
        errorMessage = nil
        pending = row
    }

    func confirm(_ row: Row) async {
        pending = nil
        do {
            try await switcher.set(row.iconName)
            current = switcher.current()
        } catch {
            errorMessage = String(localized: "Couldn't change the app icon. Try again.", bundle: .app)
        }
    }
}
