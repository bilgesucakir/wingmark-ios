import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark

    static let storageKey = "appAppearance"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: String(localized: "System", bundle: .app)
        case .light: String(localized: "Light", bundle: .app)
        case .dark: String(localized: "Dark", bundle: .app)
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

extension UnitPreference {
    private static let storageKey = "unitPreference"

    /// Cached locally so formatting works before settings load and offline.
    static var current: UnitPreference {
        get { UserDefaults.standard.string(forKey: storageKey).flatMap(UnitPreference.init(rawValue:)) ?? .metric }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: storageKey) }
    }

    var title: String {
        switch self {
        case .metric: String(localized: "Metric (m, km)", bundle: .app)
        case .imperial: String(localized: "Imperial (ft, mi)", bundle: .app)
        }
    }

    /// Short distances in m/ft, longer ones in km/mi.
    func format(meters: Double, locale: Locale = .app) -> String {
        let measurement = Measurement(value: meters, unit: UnitLength.meters)
        let style = Measurement<UnitLength>.FormatStyle.measurement(
            width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(0...1))
        ).locale(locale)
        switch self {
        case .metric:
            return meters < 1000 ? measurement.formatted(style) : measurement.converted(to: .kilometers).formatted(style)
        case .imperial:
            let feet = measurement.converted(to: .feet)
            return feet.value < 1000 ? feet.formatted(style) : measurement.converted(to: .miles).formatted(style)
        }
    }
}
