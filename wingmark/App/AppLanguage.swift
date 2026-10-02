import Foundation

nonisolated enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case turkish = "tr"

    static let storageKey = "appLanguage"

    var id: String { rawValue }

    var code: String { rawValue }

    var displayName: String {
        switch self {
        case .english: "English"
        case .turkish: "Türkçe"
        }
    }

    var locale: Locale { Locale(identifier: rawValue) }

    /// Used until the person picks a language: Turkish on a Turkish device, English everywhere else.
    static func deviceDefault(preferredLanguages: [String] = Locale.preferredLanguages) -> AppLanguage {
        preferredLanguages.first?.lowercased().hasPrefix("tr") == true ? .turkish : .english
    }

    static var current: AppLanguage {
        UserDefaults.standard.string(forKey: storageKey).flatMap(AppLanguage.init(rawValue:)) ?? deviceDefault()
    }
}

extension Bundle {
    /// Follows the in-app language rather than the device language.
    nonisolated static var app: Bundle {
        guard let path = Bundle.main.path(forResource: AppLanguage.current.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path)
        else { return .main }
        return bundle
    }
}

extension Locale {
    nonisolated static var app: Locale { AppLanguage.current.locale }
}
