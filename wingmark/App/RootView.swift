import SwiftUI

struct RootView: View {
    @Environment(AuthSession.self) private var session

    var body: some View {
        switch session.state {
        case .launching:
            ProgressView()
        case .signedOut, .needsVerification:
            ContentUnavailableView {
                Label("Wingmark", systemImage: "bird")
            } description: {
                Text("Sign-in screens are coming next.")
                Text(session.client.baseURL.absoluteString)
                    .font(.footnote.monospaced())
            }
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
}

#Preview {
    RootView()
        .environment(AuthSession(client: APIClient(tokenStore: InMemoryTokenStore())))
}
