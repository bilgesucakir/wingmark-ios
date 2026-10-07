import SwiftUI
import TipKit

@main
struct WingmarkApp: App {
    init() {
        try? Tips.configure()
    }

    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @State private var session = AuthSession(client: APIClient(tokenStore: KeychainTokenStore()))
    @AppStorage(AppLanguage.storageKey) private var language = AppLanguage.current
    @AppStorage(AppAppearance.storageKey) private var appearance = AppAppearance.system

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .environment(AppRouter.shared)
                .environment(\.locale, language.locale)
                .preferredColorScheme(appearance.colorScheme)
                .onOpenURL { url in
                    if let link = AppLink(url: url) { AppRouter.shared.open(link) }
                }
                .onChange(of: language, initial: true) {
                    QuickAction.install()
                    WidgetSync.saveLanguage(language.code)
                }
                .task {
                    LocalData.clearSessionFromPreviousInstall(session.client.tokenStore)
                    await session.restore()
                }
        }
    }
}
