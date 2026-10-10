import SwiftUI

/// The feature pages after the welcome page. Copy sticks to what the app does today.
enum OnboardingPage: CaseIterable, Identifiable {
    case log, map, guide, badges

    var id: Self { self }

    /// Shown when a page has no picture of its own.
    var symbol: String {
        switch self {
        case .log: "camera.fill"
        case .map: "map.fill"
        case .guide: "text.book.closed.fill"
        case .badges: "trophy.fill"
        }
    }

    var title: String {
        switch self {
        case .log: String(localized: "Log what you see", bundle: .app)
        case .map: String(localized: "See your sightings on a map", bundle: .app)
        case .guide: String(localized: "Learn about the species", bundle: .app)
        case .badges: String(localized: "Earn badges", bundle: .app)
        }
    }

    var message: String {
        switch self {
        case .log: String(localized: "Add a photo, and the place and time can fill in for you. Pick the species, or mark it as a guess.", bundle: .app)
        case .map: String(localized: "Every bird you log becomes a pin. Filter the map by identification, gender or life stage.", bundle: .app)
        case .guide: String(localized: "Browse species in the Guide, read about them and listen to recordings.", bundle: .app)
        case .badges: String(localized: "Unlock badges as your diary grows. Some of them are secret.", bundle: .app)
        }
    }
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    /// Room above the content, for a close button that floats over the page.
    var topInset: CGFloat = 24
    /// Room below the content, for page dots that float over the page.
    var bottomInset: CGFloat = 72
    @ScaledMetric(relativeTo: .largeTitle) private var iconSize = 64
    @Environment(\.colorScheme) private var colorScheme

    /// The screenshot of the map for this language and appearance, once it has been added to the asset catalog.
    private var mapImageName: String? {
        let name = "OnboardingMap-\(AppLanguage.current.code)-\(colorScheme == .dark ? "dark" : "light")"
        return UIImage(named: name) != nil ? name : nil
    }

    var body: some View {
        // A page shorter than the screen sits in the middle of it; a taller one scrolls.
        GeometryReader { proxy in
            ScrollView {
                content
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .accessibilityElement(children: .combine)
    }

    var content: some View {
        VStack(spacing: 20) {
            preview
            Text(page.title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text(page.message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.top, topInset)
        .padding(.bottom, bottomInset)
    }

    @ViewBuilder
    private var preview: some View {
        switch page {
        case .log: SamplePanel(framed: false) { SampleLogCard() }
        case .guide: SamplePanel(framed: false) { SampleSpeciesCard() }
        case .badges: SamplePanel(framed: false) { SampleBadgeCard() }
        case .map where mapImageName != nil:
            SamplePanel(framed: false) {
                Image(mapImageName ?? "")
                    .resizable()
                    .scaledToFit()
                    .clipShape(.rect(cornerRadius: 16))
            }
        default:
            Image(systemName: page.symbol)
                .font(.system(size: iconSize))
                .foregroundStyle(.tint)
                .padding(.vertical, 40)
                .accessibilityHidden(true)
        }
    }
}

/// A small copy of an app screen that can't be tapped or scrolled, with the page colors the real screen has.
private struct SamplePanel<Content: View>: View {
    /// A grey frame around the sample. In dark mode it is as dark as the page, so only the pages that need one keep it.
    var framed = true
    @ViewBuilder let content: Content

    var body: some View {
        if framed {
            content
                .allowsHitTesting(false)
                .padding(12)
                .background(Color(.systemGroupedBackground), in: .rect(cornerRadius: 24))
                .accessibilityHidden(true)
        } else {
            content
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

/// The European Robin as the Guide shows it. The photo is bundled so this works before anyone has an account.
private struct SampleSpeciesCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image("SampleSpecies")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 140)
                .clipped()
                .traitChips(lifeStage: .adult, gender: nil)
                .clipShape(.rect(cornerRadius: 16))
            Text("Photo: Alexis Lours / Wikimedia Commons, CC BY 4.0")
                .font(.system(size: 9.5))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("European Robin").font(.title3.bold())
                    Text(verbatim: "Erithacus rubecula").italic().foregroundStyle(.secondary)
                }
                Divider()
                LabeledContent("Family") { Text(verbatim: "Muscicapidae").foregroundStyle(.secondary) }
                Divider()
                LabeledContent("Order") { Text(verbatim: "Passeriformes").foregroundStyle(.secondary) }
                Divider()
                Text("Small insectivorous bird best known for its bright orange-red breast and face.")
                    .font(.subheadline)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 16))
        }
    }
}

/// One earned badge as the Badges tab shows it.
private struct SampleBadgeCard: View {
    private let badge = BadgeProgress(
        id: UUID(), name: String(localized: "First Sighting", bundle: .app),
        description: nil, icon: "🐦", tier: .bronze, earned: true,
        earnedAt: Date(timeIntervalSince1970: 1_790_000_000), progress: 1, target: 1
    )

    var body: some View {
        BadgeCard(badge: badge, fill: Color(.secondarySystemBackground))
            .frame(maxWidth: 190)
    }
}

/// A logged sighting as its detail screen shows it, so the first page shows what ends up in the diary.
private struct SampleLogCard: View {
    private static let seen = Date(timeIntervalSince1970: 1_759_390_380)

    private func row(_ title: LocalizedStringKey, @ViewBuilder value: () -> some View) -> some View {
        LabeledContent { value().foregroundStyle(.secondary) } label: { Text(title) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image("SampleGull")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 150)
                .clipped()
                .traitChips(lifeStage: .baby, gender: nil)
                .clipShape(.rect(cornerRadius: 16))
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Juvenile Seagull").font(.title3.bold())
                    Text("European Herring Gull").foregroundStyle(.secondary)
                }
                Divider()
                row("Seen") { Text(Self.seen, format: .dateTime.day().month(.wide).year().hour().minute()) }
                Divider()
                row("Identification") { Text(SpeciesStatus.confident.title) }
                Divider()
                row("Life Stage") { Text(LifeStage.baby.title) }
                Divider()
                row("Gender") { Text(Gender.unknown.title) }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 16))
        }
    }
}
