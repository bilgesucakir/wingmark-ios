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

struct SummaryEntry: TimelineEntry {
    let date: Date
    let summary: WidgetSummary?
    let photo: UIImage?

    var language: String? { summary?.language }
    func text(_ key: WidgetText.Key) -> String { WidgetText.string(key, language: language) }
}

/// Reads what the app saved. Nothing here talks to the server or holds a token.
struct SummaryProvider: TimelineProvider {
    private func entry() -> SummaryEntry {
        let store = SharedStore.live
        let photo = store.photoURL.flatMap { try? Data(contentsOf: $0) }.flatMap { UIImage(data: $0) }
        return SummaryEntry(date: .now, summary: store.read(), photo: photo)
    }

    func placeholder(in context: Context) -> SummaryEntry {
        SummaryEntry(date: .now, summary: .sample, photo: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (SummaryEntry) -> Void) {
        completion(context.isPreview ? SummaryEntry(date: .now, summary: .sample, photo: nil) : entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SummaryEntry>) -> Void) {
        // The app asks for a reload whenever the diary or badges change; this is only a fallback.
        completion(Timeline(entries: [entry()], policy: .after(.now.addingTimeInterval(6 * 3600))))
    }
}

extension WidgetSummary {
    static let sample = WidgetSummary(
        language: "en",
        nextBadge: .init(id: nil, name: "Gathering Finder", icon: "trophy.fill", progress: 7, target: 10),
        allBadgesEarned: false,
        latest: .init(id: UUID(), name: "House Sparrow", observedAt: .now.addingTimeInterval(-7200), hasPhoto: false,
                      gender: "Female", lifeStage: "Adult", note: "Feeding under the bench near the pond.")
    )
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
        .supportedFamilies([.systemSmall, .accessoryCircular])
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
                .accessibilityLabel(Text("\(badge.name), \(badge.progress) of \(badge.target)"))
            } else {
                VStack(spacing: 6) {
                    ZStack {
                        Circle().stroke(.quaternary, lineWidth: 8)
                        Circle()
                            .trim(from: 0, to: badge.fraction)
                            .stroke(.tint, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        BadgeSymbol(icon: badge.icon).font(.title2)
                    }
                    .frame(width: 64, height: 64)
                    Text(badge.name)
                        .font(.footnote.weight(.semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    Text("\(badge.progress) / \(badge.target)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
        } else {
            Placeholder(entry: entry, message: message)
        }
    }

    private var message: WidgetText.Key {
        guard let summary = entry.summary else { return .logIn }
        return summary.allBadgesEarned ? .allEarned : .openToStart
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
                    if let traits = latest.traits {
                        Text(traits).font(.subheadline)
                    }
                    Text(latest.observedAt, style: .relative)
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
            .accessibilityElement(children: .combine)
        } else {
            Placeholder(entry: entry, message: entry.summary == nil ? .logIn : .noSightings)
        }
    }

    @ViewBuilder
    private var photo: some View {
        if let image = entry.photo {
            Image(uiImage: image).resizable().scaledToFill()
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
