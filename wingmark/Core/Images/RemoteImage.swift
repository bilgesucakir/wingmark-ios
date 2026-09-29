import SwiftUI
import UIKit

/// `/uploads/<file>` images never change, so they're cached by URL in memory and on disk.
final class ImageLoader {
    static let shared = ImageLoader()

    private let session: URLSession
    private let memory = NSCache<NSURL, UIImage>()

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = URLCache(memoryCapacity: 16 << 20, diskCapacity: 512 << 20)
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        session = URLSession(configuration: configuration)
    }

    func cachedImage(for url: URL) -> UIImage? {
        memory.object(forKey: url as NSURL)
    }

    func image(for url: URL) async -> UIImage? {
        if let cached = cachedImage(for: url) { return cached }
        guard let (data, response) = try? await session.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let image = UIImage(data: data)
        else { return nil }
        memory.setObject(image, forKey: url as NSURL)
        return image
    }
}

struct RemoteImage: View {
    @Environment(AuthSession.self) private var session
    let path: String?
    var contentMode: ContentMode = .fill

    @State private var image: UIImage?
    @State private var failed = false

    private var url: URL? { path.flatMap { session.client.assetURL(for: $0) } }

    var body: some View {
        ZStack {
            if let image = image ?? url.flatMap({ ImageLoader.shared.cachedImage(for: $0) }) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                Rectangle()
                    .fill(.quaternary)
                    .overlay {
                        if failed || url == nil {
                            Image(systemName: "bird")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        } else {
                            ProgressView()
                        }
                    }
            }
        }
        .task(id: url) {
            guard let url else { return }
            failed = false
            image = await ImageLoader.shared.image(for: url)
            failed = image == nil
        }
    }
}
