import SwiftUI

@main
struct WingmarkApp: App {
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
