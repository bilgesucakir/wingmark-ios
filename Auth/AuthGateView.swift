import SwiftUI

/// Shows the mock login/sign-up flow until `AuthSession` has a user, then
/// hands off to the app's main tab UI.
struct AuthGateView: View {
    @Environment(AuthSession.self) private var session
    @State private var showSignUp = false

    var body: some View {
        if session.isAuthenticated {
            RootTabView()
        } else if showSignUp {
            SignUpView(showSignUp: $showSignUp)
        } else {
            LoginView(showSignUp: $showSignUp)
        }
    }
}

#Preview {
    AuthGateView()
        .environment(AuthSession())
}
