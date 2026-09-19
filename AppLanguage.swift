import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english = "en"
    case turkish = "tr"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: String(localized: "System Default")
        case .english: "English"
        case .turkish: "Türkçe"
        }
    }

    /// nil means "follow the device's own language settings" — don't override the environment locale.
    var locale: Locale? {
        switch self {
        case .system: nil
        case .english: Locale(identifier: "en")
        case .turkish: Locale(identifier: "tr")
        }
    }
}
