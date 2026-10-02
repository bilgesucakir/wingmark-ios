import Foundation

enum LocalData {
    /// Removes everything the app keeps on the device: preferences, cached responses, images and recordings, temp files.
    static func wipe(defaults: UserDefaults = .standard, fileManager: FileManager = .default) {
        if let domain = Bundle.main.bundleIdentifier {
            defaults.removePersistentDomain(forName: domain)
        }
        URLCache.shared.removeAllCachedResponses()
        ImageLoader.shared.clear()
        for directory in [URL.cachesDirectory, URL.temporaryDirectory] {
            let items = (try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
            items.forEach { try? fileManager.removeItem(at: $0) }
        }
    }
}
