import SwiftUI
import TipKit

@main
struct WingmarkApp: App {
    init() {
        try? Tips.configure()
    }

    @State private var session = AuthSession(client: APIClient(tokenStore: KeychainTokenStore()))
    @AppStorage(AppLanguage.storageKey) private var language = AppLanguage.current
    @AppStorage(AppAppearance.storageKey) private var appearance = AppAppearance.system

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .environment(\.locale, language.locale)
                .preferredColorScheme(appearance.colorScheme)
                .task {
                    LocalData.clearSessionFromPreviousInstall(session.client.tokenStore)
                    await session.restore()
                }
        }
    }
}
