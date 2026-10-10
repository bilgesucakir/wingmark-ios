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

/// The carousel is a pitch for new people, so it shows only on the first launch after installing, never on later sign-ins.
struct WelcomeTour {
    static let seenKey = "hasSeenWelcomeTour"

    var defaults: UserDefaults = .standard

    var isFirstLaunch: Bool { !defaults.bool(forKey: Self.seenKey) }

    func markSeen() { defaults.set(true, forKey: Self.seenKey) }
}

struct WelcomeView: View {
    @Environment(AuthSession.self) private var session
    @Binding var path: [AuthRoute]
    @State private var page = 0
    @State private var showsGuide = false
    /// The pages only show when the app was just installed; after that the first page is all there is.
    private let showsTour = WelcomeTour().isFirstLaunch
    @Environment(\.dynamicTypeSize) private var typeSize

    /// At the accessibility text sizes the buttons alone fill the screen, so the page scrolls and the pages get a fixed height.
    var body: some View {
        if typeSize.isAccessibilitySize {
            ScrollView { content }
                .scrollBounceBehavior(.basedOnSize)
                .toolbar(.hidden, for: .navigationBar)
        } else {
            content
                .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var content: some View {
        VStack(spacing: 16) {
            if showsTour {
                TabView(selection: $page) {
                    introPage.tag(0)
                    ForEach(Array(OnboardingPage.allCases.enumerated()), id: \.element) { index, item in
                        OnboardingPageView(page: item).tag(index + 1)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                // The system dots are white, so the background keeps them visible on a light screen.
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                .frame(height: typeSize.isAccessibilitySize ? 600 : nil)
            } else {
                introPage
            }

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
            Button("Browse the Guide", systemImage: "book") { showsGuide = true }
                .font(.footnote.weight(.semibold))
            LegalLinks()
        }
        .padding(24)
        .onAppear { WelcomeTour().markSeen() }
        .sheet(isPresented: $showsGuide) {
            GuestGuideView()
                .opensLinksInApp()
        }
    }

    private var introPage: some View {
        ScrollView {
            VStack(spacing: 12) {
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 96)
                    .accessibilityHidden(true)
                Text("Wingmark")
                    .font(.largeTitle.bold())
                Text("Log the birds you see, learn about their species and earn badges along the way.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.bottom, 48)
            .containerRelativeFrame(.vertical, alignment: .center)
        }
        .scrollBounceBehavior(.basedOnSize)
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
