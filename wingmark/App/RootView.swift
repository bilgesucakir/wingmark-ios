import SwiftUI

struct RootView: View {
    @Environment(AuthSession.self) private var session
    @AppStorage(AppLanguage.storageKey) private var language = AppLanguage.current

    var body: some View {
        Group {
            switch session.state {
            case .launching:
                ProgressView()
            case .signedOut:
                AuthFlowView()
            case .needsVerification(let email):
                CheckInboxView(email: email)
            case .signedIn:
                // Rebuilding on a language change re-resolves every string and refetches server-localized names.
                MainTabView()
                    .id(language)
            }
        }
        .animation(.default, value: session.state)
        .onChange(of: language) { _, newValue in
            Task {
                try? await session.updateSettings(locale: newValue.code)
                await session.refreshProfile()
            }
        }
    }
}

#Preview {
    RootView()
        .environment(AuthSession(client: APIClient(tokenStore: InMemoryTokenStore())))
}
