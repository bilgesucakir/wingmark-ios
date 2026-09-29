import SwiftUI

@main
struct WingmarkApp: App {
    @State private var session = AuthSession(client: APIClient(tokenStore: KeychainTokenStore()))
    @AppStorage(AppLanguage.storageKey) private var languageRaw = AppLanguage.system.rawValue
    @AppStorage(AppAppearance.storageKey) private var appearance = AppAppearance.system

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .environment(\.locale, AppLanguage(rawValue: languageRaw)?.locale ?? .autoupdatingCurrent)
                .preferredColorScheme(appearance.colorScheme)
                .task { await session.restore() }
        }
    }
}
