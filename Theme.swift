import SwiftUI

enum Theme {
    // Pastel-dark: muted plum/navy rather than a flat black.
    static let background = Color(red: 0.13, green: 0.12, blue: 0.18)
    static let backgroundElevated = Color(red: 0.18, green: 0.17, blue: 0.24)
    static let accent = Color(red: 0.78, green: 0.68, blue: 0.85)
    static let textPrimary = Color(red: 0.93, green: 0.91, blue: 0.96)
    static let textSecondary = Color(red: 0.93, green: 0.91, blue: 0.96).opacity(0.6)
}

extension Font {
    /// Thin, italic, flowing display type for screen titles.
    static func flowing(_ size: CGFloat) -> Font {
        .custom("SnellRoundhand", size: size)
    }
}

/// Pastel-dark page background that extends under the liquid-glass tab bar.
struct ThemedBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(Theme.background)
    }
}

extension View {
    func themedBackground() -> some View {
        modifier(ThemedBackground())
    }
}

/// Flowing-script screen title, used in place of the default nav title style.
struct FlowingTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.flowing(34))
            .foregroundStyle(Theme.textPrimary)
    }
}
