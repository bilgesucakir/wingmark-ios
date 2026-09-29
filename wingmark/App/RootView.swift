import SwiftUI

struct RootView: View {
    @Environment(AuthSession.self) private var session

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
                MainTabView()
            }
        }
        .animation(.default, value: session.state)
    }
}

#Preview {
    RootView()
        .environment(AuthSession(client: APIClient(tokenStore: InMemoryTokenStore())))
}
