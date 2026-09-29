import SwiftUI

enum AuthRoute: Hashable {
    case login
    case signUp
    case forgotPassword(email: String)
    case resetPassword(email: String)
}

struct AuthFlowView: View {
    @State private var path: [AuthRoute] = []
    @State private var loginNotice: LocalizedStringKey?

    var body: some View {
        NavigationStack(path: $path) {
            WelcomeView(path: $path)
                .navigationDestination(for: AuthRoute.self) { route in
                    switch route {
                    case .login:
                        LoginView(path: $path, notice: $loginNotice)
                    case .signUp:
                        SignUpView(path: $path)
                    case .forgotPassword(let email):
                        ForgotPasswordView(path: $path, initialEmail: email)
                    case .resetPassword(let email):
                        ResetPasswordView(email: email) {
                            loginNotice = "Your password was reset. Log in with your new password."
                            path = [.login]
                        }
                    }
                }
        }
    }
}

struct WelcomeView: View {
    @Environment(AuthSession.self) private var session
    @Binding var path: [AuthRoute]

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "bird.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                Text("Wingmark")
                    .font(.largeTitle.bold())
                Text("Log the birds you see, learn every species and earn badges along the way.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            if session.accountDeletedNotice {
                Label("Your account has been deleted.", systemImage: "checkmark.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if session.sessionExpiredNotice {
                Label("Your session has ended. Please log in again.", systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(spacing: 12) {
                Button {
                    path.append(.login)
                } label: {
                    Text("Log In").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    path.append(.signUp)
                } label: {
                    Text("Create Account").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .controlSize(.large)
        }
        .padding(24)
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview {
    AuthFlowView()
        .environment(AuthSession(client: APIClient(tokenStore: InMemoryTokenStore())))
}
