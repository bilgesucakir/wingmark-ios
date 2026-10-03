import Foundation

enum LocalData {
    private static let installMarkerKey = "hasLaunchedBefore"

    /// The Keychain survives deleting the app but UserDefaults doesn't, so a missing marker means a fresh install
    /// whose leftover tokens shouldn't silently sign the previous user back in.
    static func clearSessionFromPreviousInstall(_ tokenStore: TokenStore, defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: installMarkerKey) else { return }
        tokenStore.clear()
        defaults.set(true, forKey: installMarkerKey)
    }

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
