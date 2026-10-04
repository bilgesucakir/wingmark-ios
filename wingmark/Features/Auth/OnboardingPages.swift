import SwiftUI

/// The feature pages after the welcome page. Copy sticks to what the app does today.
enum OnboardingPage: CaseIterable, Identifiable {
    case log, map, learn

    var id: Self { self }

    var symbol: String {
        switch self {
        case .log: "camera.fill"
        case .map: "map.fill"
        case .learn: "trophy.fill"
        }
    }

    var title: String {
        switch self {
        case .log: String(localized: "Log what you see", bundle: .app)
        case .map: String(localized: "See your sightings on a map", bundle: .app)
        case .learn: String(localized: "Learn and earn badges", bundle: .app)
        }
    }

    var message: String {
        switch self {
        case .log: String(localized: "Add a photo, and the place and time can fill in for you. Pick the species, or mark it as a guess.", bundle: .app)
        case .map: String(localized: "Every bird you log becomes a pin. Filter the map by identification, gender or life stage.", bundle: .app)
        case .learn: String(localized: "Browse species in the Guide, listen to recordings, and earn badges as your diary grows.", bundle: .app)
        }
    }
}

struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: page.symbol)
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                Text(page.title)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text(page.message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.bottom, 48)
            .containerRelativeFrame(.vertical, alignment: .center)
        }
        .scrollBounceBehavior(.basedOnSize)
        .accessibilityElement(children: .combine)
    }
}

/// The system page dots are white on white here, so these are drawn in the accent color. VoiceOver can adjust the page.
struct PageDots: View {
    let count: Int
    @Binding var selection: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(index == selection ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.secondary.opacity(0.35)))
                    .frame(width: 8, height: 8)
            }
        }
        .animation(.default, value: selection)
        .accessibilityElement()
        .accessibilityLabel(Text("Page \(selection + 1) of \(count)"))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: selection = min(selection + 1, count - 1)
            case .decrement: selection = max(selection - 1, 0)
            @unknown default: break
            }
        }
    }
}
