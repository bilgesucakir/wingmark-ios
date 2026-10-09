import Foundation

/// What the widgets show. The app writes it into the shared App Group folder; a widget only reads it, so it never
/// needs a token. It leaves out places and coordinates on purpose.
nonisolated struct WidgetSummary: Codable, Equatable, Sendable {
    struct Badge: Codable, Equatable, Sendable {
        /// Missing in summaries saved by older builds; the widget then opens the badge list.
        var id: UUID?
        var name: String
        /// Every language the catalog has, so the widget can follow the app's language without waiting for the app to rewrite this.
        var names: [String: String]?
        var icon: String?
        var progress: Int
        var target: Int

        var fraction: Double {
            target > 0 ? min(Double(progress) / Double(target), 1) : 0
        }

        func displayName(language: String?) -> String {
            language.flatMap { names?[$0] } ?? name
        }
    }

    struct Sighting: Codable, Equatable, Sendable {
        var id: UUID
        var name: String
        var observedAt: Date
        var hasPhoto: Bool
        /// Shown as written in the app's language; left out when unknown.
        var gender: String?
        var lifeStage: String?
        /// The server's values ("FEMALE", "BABY"), so the widget can write them in the app's language itself.
        var genderCode: String?
        var lifeStageCode: String?
        var note: String?

        /// "Female · Juvenile", or nothing when neither is known.
        func traits(language: String?) -> String? {
            let parts = [
                genderCode.flatMap { WidgetText.trait($0, language: language) } ?? (genderCode == nil ? gender : nil),
                lifeStageCode.flatMap { WidgetText.trait($0, language: language) } ?? (lifeStageCode == nil ? lifeStage : nil),
            ].compactMap { $0 }
            return parts.isEmpty ? nil : parts.joined(separator: " · ")
        }
    }

    var language: String
    var nextBadge: Badge?
    var allBadgesEarned: Bool
    var latest: Sighting?
}

nonisolated struct SharedStore: Sendable {
    static let groupID = "group.com.bilgesucakir.wingmark"

    var directory: URL?

    static let live = SharedStore(directory: FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID))

    private var summaryURL: URL? { directory?.appending(path: "widget-summary.json") }
    var photoURL: URL? { directory?.appending(path: "latest-sighting.jpg") }

    func read() -> WidgetSummary? {
        guard let url = summaryURL, let data = try? Data(contentsOf: url) else { return nil }
        return try? Self.decoder.decode(WidgetSummary.self, from: data)
    }

    func write(_ summary: WidgetSummary) {
        guard let url = summaryURL, let data = try? Self.encoder.encode(summary) else { return }
        try? data.write(to: url, options: .atomic)
    }

    func writePhoto(_ data: Data?) {
        guard let url = photoURL else { return }
        if let data {
            try? data.write(to: url, options: .atomic)
        } else {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private var languageURL: URL? { directory?.appending(path: "language.txt") }
    private var birdURL: URL? { directory?.appending(path: "bird-of-the-day.json") }
    var birdPhotoURL: URL? { directory?.appending(path: "bird-of-the-day.jpg") }

    /// Saved even when signed out, so the Bird of the Day widget speaks the app's language before anyone logs in.
    func readLanguage() -> String? {
        languageURL.flatMap { try? String(contentsOf: $0, encoding: .utf8) }
    }

    func writeLanguage(_ code: String) {
        guard let url = languageURL else { return }
        try? code.write(to: url, atomically: true, encoding: .utf8)
    }

    /// The last bird fetched, kept for when the phone is offline. It is public Guide data, so `clear()` leaves it.
    func readBird() -> BirdOfTheDay? {
        guard let url = birdURL, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(BirdOfTheDay.self, from: data)
    }

    func writeBird(_ bird: BirdOfTheDay, photo: Data?) {
        guard let url = birdURL, let data = try? JSONEncoder().encode(bird) else { return }
        try? data.write(to: url, options: .atomic)
        if let photo, let photoURL = birdPhotoURL {
            try? photo.write(to: photoURL, options: .atomic)
        } else if let photoURL = birdPhotoURL {
            try? FileManager.default.removeItem(at: photoURL)
        }
    }

    /// Signed out or account deleted: nothing about the person stays behind.
    func clear() {
        for url in [summaryURL, photoURL].compactMap({ $0 }) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

/// The widgets follow the app's language setting, which the phone's own language doesn't tell them.
nonisolated enum WidgetText {
    enum Key: CaseIterable {
        case nextBadge, latestSighting, logIn, allEarned, noSightings, openToStart, birdOfTheDay, photoCredit, noBird

        fileprivate var english: String {
            switch self {
            case .nextBadge: "Next badge"
            case .latestSighting: "Latest sighting"
            case .logIn: "Log in to Wingmark"
            case .allEarned: "All badges earned"
            case .noSightings: "No sightings yet"
            case .openToStart: "Open Wingmark"
            case .birdOfTheDay: "Bird of the day"
            case .photoCredit: "Photo:"
            case .noBird: "Couldn't load a bird"
            }
        }

        fileprivate var turkish: String {
            switch self {
            case .nextBadge: "Sıradaki rozet"
            case .latestSighting: "Son gözlem"
            case .logIn: "Wingmark'a giriş yap"
            case .allEarned: "Tüm rozetler kazanıldı"
            case .noSightings: "Henüz gözlem yok"
            case .openToStart: "Wingmark'ı aç"
            case .birdOfTheDay: "Günün kuşu"
            case .photoCredit: "Fotoğraf:"
            case .noBird: "Kuş yüklenemedi"
            }
        }
    }

    /// Gender and life stage as the app writes them; unknown values give nil.
    static func trait(_ code: String, language: String?) -> String? {
        let turkish = language == "tr"
        switch code {
        case "MALE": return turkish ? "Erkek" : "Male"
        case "FEMALE": return turkish ? "Dişi" : "Female"
        case "ADULT": return turkish ? "Yetişkin" : "Adult"
        case "BABY": return turkish ? "Yavru" : "Juvenile"
        default: return nil
        }
    }

    static func string(_ key: Key, language: String?) -> String {
        language == "tr" ? key.turkish : key.english
    }

    /// When the sighting happened, in the app's language: "Today 14:30", "Yesterday 14:30", or "5 Oct 14:30" for older ones.
    /// A time never goes stale, unlike "2 hours ago", which a widget can't keep up to date.
    static func observed(_ date: Date, now: Date, language: String?, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language == "tr" ? "tr" : "en")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        let recent = calendar.isDate(date, inSameDayAs: now)
            || calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day == 1
        if recent {
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            formatter.doesRelativeDateFormatting = true
        } else {
            let sameYear = calendar.isDate(date, equalTo: now, toGranularity: .year)
            formatter.setLocalizedDateFormatFromTemplate(sameYear ? "MMMd jmm" : "yMMMd jmm")
        }
        return formatter.string(from: date)
    }
}
