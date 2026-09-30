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

extension UnitPreference {
    /// "2.3 km away" / "1.4 mi away".
    func distanceAway(meters: Double, locale: Locale = .app) -> String {
        String(localized: "\(format(meters: meters, locale: locale)) away", bundle: .app)
    }

    /// Rewrites metric lengths in free text (e.g. species sizes like "12,5-14 cm") as inches or feet.
    /// Metric text is returned unchanged.
    func convertingLengths(in text: String, locale: Locale = .app) -> String {
        guard self == .imperial else { return text }
        let pattern = /(\d+(?:[.,]\d+)?)(?:\s*[-–]\s*(\d+(?:[.,]\d+)?))?\s*(mm|cm|m)\b/
        return text.replacing(pattern) { match in
            let unit = String(match.output.3)
            guard let low = Self.number(match.output.1) else { return String(match.output.0) }
            let high = match.output.2.flatMap { Self.number($0) }
            let (factor, symbol): (Double, String) = switch unit {
            case "mm": (1 / 25.4, "in")
            case "cm": (1 / 2.54, "in")
            default: (3.28084, "ft")
            }
            let style = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(0...1)).locale(locale)
            let lowText = (low * factor).formatted(style)
            guard let high else { return "\(lowText) \(symbol)" }
            return "\(lowText)–\((high * factor).formatted(style)) \(symbol)"
        }
    }

    private static func number(_ text: Substring) -> Double? {
        Double(text.replacingOccurrences(of: ",", with: "."))
    }
}
