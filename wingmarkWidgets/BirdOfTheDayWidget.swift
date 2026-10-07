import ImageIO
import SwiftUI
import WidgetKit

struct BirdEntry: TimelineEntry {
    let date: Date
    let bird: BirdOfTheDay?
    let photo: UIImage?
    let language: String

    func text(_ key: WidgetText.Key) -> String { WidgetText.string(key, language: language) }
}

/// Fetches the day's bird itself from the public Guide, so it works before anyone logs in.
struct BirdProvider: TimelineProvider {
    private static var language: String {
        SharedStore.live.readLanguage() ?? (Locale.current.language.languageCode?.identifier == "tr" ? "tr" : "en")
    }

    func placeholder(in context: Context) -> BirdEntry {
        BirdEntry(date: .now, bird: .sample, photo: nil, language: Self.language)
    }

    func getSnapshot(in context: Context, completion: @escaping (BirdEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
        } else {
            Task { completion(await entry()) }
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BirdEntry>) -> Void) {
        Task {
            let entry = await entry()
            let tomorrow = Calendar.current.startOfDay(for: .now).addingTimeInterval(24 * 3600)
            // Offline: try again in an hour instead of waiting for midnight, while the last bird stays on screen.
            let next = entry.bird == nil ? Date.now.addingTimeInterval(3600) : tomorrow
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }

    private func entry() async -> BirdEntry {
        let store = SharedStore.live
        let language = Self.language
        let load: (URL) async throws -> Data = { try await URLSession.shared.data(from: $0).0 }
        if let bird = await BirdOfTheDayFetcher.fetch(on: .now, language: language, load: load) {
            let data = await bird.photoURL.asyncFlatMap { try? await load($0) }
            let photo = data.flatMap { Self.thumbnail(from: $0, maxPixels: 900) }
            store.writeBird(bird, photo: photo.flatMap { $0.jpegData(compressionQuality: 0.8) })
            return BirdEntry(date: .now, bird: bird, photo: photo, language: language)
        }
        let cachedPhoto = store.birdPhotoURL.flatMap { try? Data(contentsOf: $0) }.flatMap { UIImage(data: $0) }
        return BirdEntry(date: .now, bird: store.readBird(), photo: cachedPhoto, language: language)
    }

    /// Widgets have a small memory budget, so the photo is decoded at the size it is shown, never in full.
    private static func thumbnail(from data: Data, maxPixels: Int) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary).map { UIImage(cgImage: $0) }
    }
}

private extension Optional {
    func asyncFlatMap<T>(_ transform: (Wrapped) async -> T?) async -> T? {
        guard let self else { return nil }
        return await transform(self)
    }
}

extension BirdOfTheDay {
    static let sample = BirdOfTheDay(
        name: "House Sparrow", scientificName: "Passer domesticus",
        summary: "A small, social bird found in towns and farmland across much of the world.",
        photoURL: nil, credit: nil
    )
}

struct BirdOfTheDayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BirdOfTheDay", provider: BirdProvider()) { entry in
            BirdOfTheDayView(entry: entry)
                .widgetURL(AppLink.guide.url)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Bird of the Day")
        .description("A different bird from the Guide every day.")
        .supportedFamilies([.systemMedium, .systemLarge, .accessoryRectangular])
    }
}

struct BirdOfTheDayView: View {
    @Environment(\.widgetFamily) private var family
    let entry: BirdEntry

    var body: some View {
        if let bird = entry.bird {
            switch family {
            case .systemLarge: large(bird)
            case .accessoryRectangular: lockScreen(bird)
            default: medium(bird)
            }
        } else {
            VStack(spacing: 8) {
                Image(systemName: "bird.fill").font(.title).foregroundStyle(.tint)
                Text(entry.text(.noBird)).font(.footnote.weight(.semibold))
            }
        }
    }

    private func large(_ bird: BirdOfTheDay) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            photo
                .frame(maxWidth: .infinity)
                .frame(height: 170)
                .clipShape(.rect(cornerRadius: 12))
            Text(entry.text(.birdOfTheDay)).font(.caption).foregroundStyle(.secondary)
            Text(bird.name).font(.title3.bold()).lineLimit(1)
            if let scientific = bird.scientificName {
                Text(scientific).font(.subheadline).italic().foregroundStyle(.secondary).lineLimit(1)
            }
            if let summary = bird.summary {
                Text(summary).font(.footnote).lineLimit(4)
            }
            Spacer(minLength: 0)
            credit(bird)
        }
    }

    private func medium(_ bird: BirdOfTheDay) -> some View {
        HStack(spacing: 12) {
            photo
                .frame(width: 110)
                .frame(maxHeight: .infinity)
                .clipShape(.rect(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.text(.birdOfTheDay)).font(.caption).foregroundStyle(.secondary)
                Text(bird.name).font(.headline).lineLimit(2)
                if let scientific = bird.scientificName {
                    Text(scientific).font(.caption).italic().foregroundStyle(.secondary).lineLimit(1)
                }
                if let summary = bird.summary {
                    Text(summary).font(.caption).lineLimit(2)
                }
                Spacer(minLength: 0)
                credit(bird)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func lockScreen(_ bird: BirdOfTheDay) -> some View {
        VStack(alignment: .leading) {
            Text(entry.text(.birdOfTheDay)).font(.caption2).foregroundStyle(.secondary)
            Text(bird.name).font(.headline).lineLimit(1)
            if let scientific = bird.scientificName {
                Text(scientific).font(.caption).italic().lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var photo: some View {
        if let image = entry.photo {
            Image(uiImage: image).resizable().scaledToFill()
        } else {
            Rectangle().fill(.quaternary).overlay { Image(systemName: "bird").font(.title).foregroundStyle(.secondary) }
        }
    }

    @ViewBuilder
    private func credit(_ bird: BirdOfTheDay) -> some View {
        if let credit = bird.credit {
            Text("\(entry.text(.photoCredit)) \(credit)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}
