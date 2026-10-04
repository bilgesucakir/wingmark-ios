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
                            loginNotice = "Your password was reset. We've emailed you a confirmation. Log in with your new password."
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
    @State private var page = 0

    var body: some View {
        VStack(spacing: 16) {
            TabView(selection: $page) {
                introPage.tag(0)
                ForEach(Array(OnboardingPage.allCases.enumerated()), id: \.element) { index, item in
                    OnboardingPageView(page: item).tag(index + 1)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            PageDots(count: OnboardingPage.allCases.count + 1, selection: $page)

            notice
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
            LegalLinks()
        }
        .padding(24)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var introPage: some View {
        VStack(spacing: 12) {
            Image(systemName: "bird.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text("Wingmark")
                .font(.largeTitle.bold())
            Text("Log the birds you see, learn about their species and earn badges along the way.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 48)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var notice: some View {
        if session.accountDeletedNotice {
            Label("Your account has been deleted. We've sent you a confirmation email.", systemImage: "checkmark.circle")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else if session.sessionExpiredNotice {
            Label("Your session has ended. Please log in again.", systemImage: "info.circle")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    AuthFlowView()
        .environment(AuthSession(client: APIClient(tokenStore: InMemoryTokenStore())))
}
