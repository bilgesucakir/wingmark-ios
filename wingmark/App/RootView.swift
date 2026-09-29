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
                ContentUnavailableView {
                    Label(session.profile?.displayName ?? "Wingmark", systemImage: "bird")
                } description: {
                    Text("You're signed in.")
                } actions: {
                    Button("Log Out") {
                        Task { await session.logOut() }
                    }
                }
            }
        }
        .animation(.default, value: session.state)
    }
}

#Preview {
    RootView()
        .environment(AuthSession(client: APIClient(tokenStore: InMemoryTokenStore())))
}
