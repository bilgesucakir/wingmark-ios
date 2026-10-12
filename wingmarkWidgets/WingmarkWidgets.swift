import SwiftUI
import UIKit
import WidgetKit

@main
struct WingmarkWidgets: WidgetBundle {
    var body: some Widget {
        NextBadgeWidget()
        LatestSightingWidget()
        BirdOfTheDayWidget()
    }
}

/// The app's bird in one color, like the corner marks other apps put on their widgets.
struct WidgetLogo: View {
    var body: some View {
        Image("WidgetLogo")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: 22)
            .foregroundStyle(.tertiary)
            .widgetAccentable()
            .accessibilityHidden(true)
    }
}

struct SummaryEntry: TimelineEntry {
    let date: Date
    let summary: WidgetSummary?
    let photo: UIImage?
    /// The app's current language. The saved summary can still be in the previous one for a moment after a switch.
    var language: String?

    init(date: Date, summary: WidgetSummary?, photo: UIImage?, language: String? = SharedStore.live.readLanguage()) {
        self.date = date
        self.summary = summary
        self.photo = photo
        self.language = language ?? summary?.language
    }

    func text(_ key: WidgetText.Key) -> String { WidgetText.string(key, language: language) }
}

/// Reads what the app saved. Nothing here talks to the server or holds a token.
struct SummaryProvider: TimelineProvider {
    private func entry() -> SummaryEntry {
        let store = SharedStore.live
        let photo = store.photoURL.flatMap { try? Data(contentsOf: $0) }.flatMap { UIImage(data: $0) }
        return SummaryEntry(date: .now, summary: store.read(), photo: photo)
    }

    /// The widget gallery shows an example: in the phone's language, since the app's language isn't chosen yet there.
    private static var galleryEntry: SummaryEntry {
        let language = Locale.current.language.languageCode?.identifier == "tr" ? "tr" : "en"
        return SummaryEntry(date: .now, summary: .sample(language: language), photo: nil, language: language)
    }

    func placeholder(in context: Context) -> SummaryEntry { Self.galleryEntry }

    func getSnapshot(in context: Context, completion: @escaping (SummaryEntry) -> Void) {
        completion(context.isPreview ? Self.galleryEntry : entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SummaryEntry>) -> Void) {
        // The app asks for a reload whenever the diary or badges change; at midnight "Today" has to become "Yesterday".
        let midnight = Calendar.current.startOfDay(for: .now).addingTimeInterval(24 * 3600 + 60)
        completion(Timeline(entries: [entry()], policy: .after(midnight)))
    }
}

extension WidgetSummary {
    static func sample(language: String) -> WidgetSummary {
        let tr = language == "tr"
        let badges: [Badge] = [
            .init(id: nil, name: tr ? "Buluşma Bulucu" : "Gathering Finder", tier: "GOLD", description: tr ? "Birbirine 1 km mesafede 2 farklı tür bul." : "Find 2 different species within 1km of each other.", icon: "trophy.fill", progress: 7, target: 10),
            .init(id: nil, name: tr ? "Tür Kaşifi" : "Species Explorer", tier: "SILVER", icon: "magnifyingglass", progress: 4, target: 10),
            .init(id: nil, name: tr ? "Yuva Gözlemcisi" : "Nest Watcher", tier: "BRONZE", icon: "leaf.fill", progress: 1, target: 5),
        ]
        return WidgetSummary(
            language: language,
            nextBadge: badges[0],
            allBadgesEarned: false,
            latest: .init(id: UUID(), name: tr ? "Serçe" : "House Sparrow", observedAt: .now.addingTimeInterval(-7200), hasPhoto: false,
                          gender: tr ? "Dişi" : "Female", lifeStage: tr ? "Yetişkin" : "Adult",
                          note: tr ? "Gölet yanındaki bankın altında besleniyor." : "Feeding under the bench near the pond.")
        )
    }
}

// MARK: - Next badge

struct NextBadgeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NextBadge", provider: SummaryProvider()) { entry in
            NextBadgeView(entry: entry)
                .widgetURL((entry.summary?.nextBadge?.id.map { AppLink.badge($0) } ?? .badges).url)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Next Badge")
        .description("The badge you are closest to earning.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular])
    }
}

struct NextBadgeView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SummaryEntry

    var body: some View {
        if let badge = entry.summary?.nextBadge {
            if family == .accessoryCircular {
                Gauge(value: badge.fraction) {
                    BadgeSymbol(icon: badge.icon)
                } currentValueLabel: {
                    Text("\(badge.progress)")
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .accessibilityLabel(Text("\(badge.displayName(language: entry.language)), \(badge.progress) of \(badge.target)"))
            } else if family == .systemMedium {
                medium(first: badge)
            } else {
                featured(badge, size: 58)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(alignment: .topTrailing) { WidgetLogo() }
                    .accessibilityElement(children: .combine)
            }
        } else {
            Placeholder(entry: entry, message: message)
        }
    }

    /// The closest badge as a progress ring with its name, tier and count.
    private func featured(_ badge: WidgetSummary.Badge, size: CGFloat) -> some View {
        VStack(spacing: 4) {
            ring(badge, size: size)
                // Keeps the name from almost touching the ring.
                .padding(.bottom, 8)
            Text(badge.displayName(language: entry.language))
                .font(.footnote.weight(.semibold))
                .lineLimit(2)
                .multilineTextAlignment(.center)
            Text("\(WidgetText.tier(badge.tier, language: entry.language)) · \(badge.progress) / \(badge.target)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// The closest badge on the left, its details on the right: name, tier, what it asks for and how far along it is.
    private func medium(first badge: WidgetSummary.Badge) -> some View {
        HStack(spacing: 16) {
            ring(badge, size: 92)
            VStack(alignment: .leading, spacing: 4) {
                Text(badge.displayName(language: entry.language))
                    .font(.headline)
                    .lineLimit(2)
                Text(WidgetText.tier(badge.tier, language: entry.language))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(badge.ringColor)
                if let description = badge.displayDescription(language: entry.language) {
                    Text(description)
                        .font(.caption)
                        .lineLimit(3)
                }
                Spacer(minLength: 0)
                ProgressView(value: badge.fraction).tint(badge.ringColor)
                Text("\(badge.progress) / \(badge.target)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topTrailing) { WidgetLogo() }
        .accessibilityElement(children: .combine)
    }

    private func ring(_ badge: WidgetSummary.Badge, size: CGFloat) -> some View {
        ZStack {
            Circle().stroke(.quaternary, lineWidth: size / 8)
            Circle()
                .trim(from: 0, to: badge.fraction)
                .stroke(badge.ringColor, style: StrokeStyle(lineWidth: size / 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            BadgeSymbol(icon: badge.icon).font(size > 70 ? .largeTitle : .title2)
        }
        .frame(width: size, height: size)
    }

    private var message: WidgetText.Key {
        guard let summary = entry.summary else { return .logIn }
        return summary.allBadgesEarned ? .allEarned : .openToStart
    }
}

extension WidgetSummary.Badge {
    /// The tier color, darkened a little so a gold or frosted-blue ring still shows on a light widget.
    var ringColor: Color {
        let rgb = TierPalette.rgb(tier)
        return Color(red: rgb.red, green: rgb.green, blue: rgb.blue).mix(with: .black, by: 0.3)
    }
}

struct BadgeSymbol: View {
    let icon: String?

    var body: some View {
        let value = icon?.trimmingCharacters(in: .whitespaces) ?? ""
        if value.isEmpty {
            Image(systemName: "trophy.fill")
        } else if value.allSatisfy({ $0.isASCII }), UIImage(systemName: value) != nil {
            Image(systemName: value)
        } else {
            Text(value)
        }
    }
}

// MARK: - Latest sighting

struct LatestSightingWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LatestSighting", provider: SummaryProvider()) { entry in
            LatestSightingView(entry: entry)
                .widgetURL(entry.summary?.latest.map { AppLink.sighting($0.id).url })
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Latest Sighting")
        .description("The last bird you logged.")
        .supportedFamilies([.systemMedium])
    }
}

struct LatestSightingView: View {
    let entry: SummaryEntry

    var body: some View {
        if let latest = entry.summary?.latest {
            HStack(spacing: 12) {
                // The photo is cropped to a fixed-width slot; otherwise its natural size pushes the text out of the widget.
                Color.clear
                    .frame(width: 96)
                    .overlay { photo }
                    .clipShape(.rect(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.text(.latestSighting))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(latest.name)
                        .font(.headline)
                        .lineLimit(latest.note == nil ? 2 : 1)
                    if let traits = latest.traits(language: entry.language) {
                        Text(traits).font(.subheadline)
                    }
                    Text(WidgetText.observed(latest.observedAt, now: entry.date, language: entry.language))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let note = latest.note {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .topTrailing) { WidgetLogo() }
            .accessibilityElement(children: .combine)
        } else {
            Placeholder(entry: entry, message: entry.summary == nil ? .logIn : .noSightings)
        }
    }

    @ViewBuilder
    private var photo: some View {
        if let image = entry.photo {
            Image(uiImage: image).resizable().widgetAccentedRenderingMode(.accentedDesaturated).scaledToFill()
        } else {
            Rectangle().fill(.quaternary).overlay { Image(systemName: "bird").font(.title).foregroundStyle(.secondary) }
        }
    }
}

struct Placeholder: View {
    let entry: SummaryEntry
    let message: WidgetText.Key

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "bird.fill").font(.title).foregroundStyle(.tint)
            Text(entry.text(message))
                .font(.footnote.weight(.semibold))
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
    }
}
