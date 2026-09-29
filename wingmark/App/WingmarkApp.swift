import SwiftUI

@main
struct WingmarkApp: App {
    @State private var session = AuthSession(client: APIClient(tokenStore: KeychainTokenStore()))
    @AppStorage(AppLanguage.storageKey) private var languageRaw = AppLanguage.system.rawValue

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .environment(\.locale, AppLanguage(rawValue: languageRaw)?.locale ?? .autoupdatingCurrent)
                .task { await session.restore() }
        }
    }
}
