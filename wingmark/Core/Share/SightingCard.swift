import LinkPresentation
import SwiftUI
import UIKit

/// The picture that gets shared: the sighting's own photo, its details and the app mark on dark grey. No location is included.
struct SightingCard: View {
    static let width: CGFloat = 1080
    private static let inset: CGFloat = 56

    let photo: UIImage
    let log: BirdLog

    private var photoHeight: CGFloat {
        let ratio = photo.size.height / max(photo.size.width, 1)
        return (Self.width - Self.inset * 2) * min(max(ratio, 0.75), 1.25)
    }

    private var hasSpecies: Bool { log.speciesCommonName != nil }
    private var title: String { log.displayName }
    private var species: String? { log.customName?.trimmingCharacters(in: .whitespaces).isEmpty == false ? log.speciesCommonName : nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 36) {
            Image(uiImage: photo)
                .resizable()
                .scaledToFill()
                .frame(width: Self.width - Self.inset * 2, height: photoHeight)
                .clipShape(.rect(cornerRadius: 56))

            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    if let species {
                        Text(title).font(.system(size: 64, weight: .bold)).lineLimit(2)
                        Text(speciesLine(species)).lineLimit(2)
                    } else {
                        Text(speciesLine(title, size: 64, weight: .bold)).lineLimit(2)
                    }
                    if isGuess {
                        Text("not confident").font(.system(size: 40)).foregroundStyle(.white.opacity(0.65))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 32)

                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    separator
                    Text(line)
                        .font(.system(size: 44))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 30)
                }
            }
            .padding(.horizontal, 8)

            HStack(spacing: 14) {
                Spacer()
                Text("Wingmark").font(.system(size: 40, weight: .semibold, design: .rounded))
                Image("ShareMark")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
            }
            .opacity(0.75)
        }
        .foregroundStyle(.white)
        .padding(Self.inset)
        .frame(width: Self.width)
        .background(Color(red: 0.2, green: 0.2, blue: 0.21), in: .rect(cornerRadius: 80))
        .environment(\.locale, .app)
        .environment(\.colorScheme, .dark)
    }

    private var isGuess: Bool { hasSpecies && log.speciesStatus == .guess }

    /// A guessed species gets "not confident" on the row below; a confident one gets nothing.
    private func speciesLine(_ name: String, size: CGFloat = 44, weight: Font.Weight = .regular) -> AttributedString {
        var text = AttributedString(name)
        text.font = .system(size: size, weight: weight)
        if size == 44 { text.foregroundColor = .white.opacity(0.65) }
        return text
    }

    private var lines: [String] {
        var lines = [log.observedAt.formatted(.dateTime.day().month(.wide).year().hour().minute().locale(.app))]
        if log.gender != .unknown { lines.append(log.gender.title) }
        if log.pet { lines.append(String(localized: "Pet", bundle: .app)) }
        return lines
    }

    private var separator: some View { Rectangle().fill(.white.opacity(0.18)).frame(height: 2) }
}

enum SightingCardRenderer {
    @MainActor
    static func loadPhoto(for log: BirdLog, load: (URL) async -> UIImage? = { await ImageLoader.shared.image(for: $0) }) async -> UIImage? {
        guard let url = log.photoUrl.flatMap({ AppConfig.assetURL(for: $0) }) else { return nil }
        return await load(url)
    }

    @MainActor
    static func render(_ photo: UIImage, log: BirdLog) -> UIImage? {
        let renderer = ImageRenderer(content: SightingCard(photo: photo, log: log))
        renderer.scale = 1
        return renderer.uiImage
    }
}

/// Opens the system share sheet straight from UIKit, so its header shows the card rather than only the app icon.
enum CardSharer {
    @MainActor
    static func present(_ image: UIImage, title: String) {
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first(where: { $0.activationState == .foregroundActive }),
              var top = scene.keyWindow?.rootViewController
        else { return }
        while let presented = top.presentedViewController { top = presented }
        let controller = UIActivityViewController(activityItems: [CardItem(image: image, title: title)], applicationActivities: nil)
        controller.popoverPresentationController?.sourceView = top.view
        top.present(controller, animated: true)
    }
}

private final class CardItem: NSObject, UIActivityItemSource {
    let image: UIImage
    let title: String

    init(image: UIImage, title: String) {
        self.image = image
        self.title = title
    }

    func activityViewControllerPlaceholderItem(_ controller: UIActivityViewController) -> Any { image }

    func activityViewController(_ controller: UIActivityViewController, itemForActivityType type: UIActivity.ActivityType?) -> Any? { image }

    func activityViewControllerLinkMetadata(_ controller: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = title
        let provider = NSItemProvider(object: image)
        metadata.imageProvider = provider
        metadata.iconProvider = provider
        return metadata
    }
}
