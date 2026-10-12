import UIKit
import WidgetKit

/// Keeps the widgets' summary in the shared folder in step with the diary and badges.
enum WidgetSync {
    /// Counts the updates, so a slow older one can tell that a newer one has started.
    private static var latestUpdate = 0

    static func summary(logs: [BirdLog], badges: [BadgeProgress], language: String) -> WidgetSummary {
        // A locked secret never shows up in a widget, not even by name.
        let visible = badges.filter { !$0.isLockedSecret }
        let ranked = visible.filter { !$0.earned && $0.target > 0 }
            .enumerated().sorted { ($0.element.fraction, -$0.offset) > ($1.element.fraction, -$1.offset) }.map(\.element)
        let next = ranked.first
        func entry(_ badge: BadgeProgress) -> WidgetSummary.Badge {
            .init(id: badge.id, name: badge.name, names: badge.names.isEmpty ? nil : badge.names, tier: badge.tier.rawValue,
                  icon: badge.icon, progress: badge.progress, target: badge.target)
        }
        let latest = logs.max { $0.observedAt < $1.observedAt }
        return WidgetSummary(
            language: language,
            nextBadge: next.map(entry),
            nextBadges: ranked.isEmpty ? nil : ranked.prefix(3).map(entry),
            allBadgesEarned: !visible.isEmpty && visible.allSatisfy(\.earned),
            latest: latest.map {
                .init(
                    id: $0.id, name: $0.displayName, observedAt: $0.observedAt, hasPhoto: $0.photoUrl != nil,
                    gender: $0.gender == .unknown ? nil : $0.gender.title,
                    lifeStage: $0.lifeStage == .unknown ? nil : $0.lifeStage.title,
                    genderCode: $0.gender == .unknown ? nil : $0.gender.rawValue,
                    lifeStageCode: $0.lifeStage == .unknown ? nil : $0.lifeStage.rawValue,
                    note: shortNote($0.note)
                )
            }
        )
    }

    /// A widget has room for a couple of lines, so a long note is cut at a word.
    static func shortNote(_ note: String?, limit: Int = 140) -> String? {
        let text = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else { return nil }
        guard text.count > limit else { return text }
        let cut = String(text.prefix(limit))
        let atWord = cut.lastIndex(of: " ").map { String(cut[..<$0]) } ?? cut
        return atWord.trimmingCharacters(in: .whitespaces) + "…"
    }

    /// `logs` must be the unfiltered diary, otherwise "latest" would be the latest match.
    static func update(
        logs: [BirdLog], badges: [BadgeProgress], language: String,
        store: SharedStore = .live, reload: () -> Void = { WidgetCenter.shared.reloadAllTimelines() },
        loadImage: (URL) async -> UIImage? = { await ImageLoader.shared.image(for: $0) },
        canWrite: () -> Bool = { true }
    ) async {
        // A photo download can take a while. If a newer update started in the meantime, this older one must not
        // write afterwards, or its older badges and sightings would replace the newer ones.
        latestUpdate += 1
        let ticket = latestUpdate
        let summary = summary(logs: logs, badges: badges, language: language)
        let previous = store.read()
        if let latest = logs.max(by: { $0.observedAt < $1.observedAt }) {
            let photoIsCurrent = previous?.latest?.id == latest.id && previous?.latest?.hasPhoto == true
                && store.photoURL.map { FileManager.default.fileExists(atPath: $0.path) } == true
            if !photoIsCurrent {
                let url = latest.photoUrl.flatMap { AppConfig.assetURL(for: $0) }
                let image = await url.asyncFlatMap(loadImage)
                // Signing out while the photo loads must not bring the old sighting back.
                guard canWrite(), ticket == latestUpdate else { return }
                store.writePhoto(image?.downscaled(toMaxSide: 600).jpegData(compressionQuality: 0.8))
            }
        } else {
            store.writePhoto(nil)
        }
        guard summary != previous, canWrite(), ticket == latestUpdate else { return }
        store.write(summary)
        reload()
    }

    static func saveLanguage(_ code: String, store: SharedStore = .live) {
        guard store.readLanguage() != code else { return }
        store.writeLanguage(code)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func clear(store: SharedStore = .live, reload: () -> Void = { WidgetCenter.shared.reloadAllTimelines() }) {
        store.clear()
        reload()
    }
}

private extension Optional {
    func asyncFlatMap<T>(_ transform: (Wrapped) async -> T?) async -> T? {
        guard let self else { return nil }
        return await transform(self)
    }
}

private extension UIImage {
    func downscaled(toMaxSide side: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > side else { return self }
        let scale = side / longest
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in draw(in: CGRect(origin: .zero, size: target)) }
    }
}
