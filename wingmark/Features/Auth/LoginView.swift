import SwiftUI

struct LoginView: View {
    @Environment(AuthSession.self) private var session
    @Binding var path: [AuthRoute]
    @Binding var notice: LocalizedStringKey?

    @State private var email = ""
    @State private var password = ""
    @State private var showValidation = false
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var isRateLimited = false
    @FocusState private var focus: Field?

    private enum Field { case email, password }

    private var emailError: String? { showValidation ? AuthValidation.emailError(email) : nil }

    var body: some View {
        Form {
            if let notice {
                Section {
                    Label(notice, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Email", text: $email)
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focus, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { focus = .password }
                    FieldError(message: emailError)
                }
                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .focused($focus, equals: .password)
                    .submitLabel(.go)
                    .onSubmit(logIn)
                // A row only when there is an error, so no empty footer pushes the button down.
                if let errorMessage {
                    FieldError(message: errorMessage)
                }
            }

            Section {
                PrimaryActionButton(title: "Log In", isLoading: isLoading, action: logIn)
                    .disabled(email.isEmpty || password.isEmpty || isLoading || isRateLimited)
            }

            Section {
                Button("Forgot Password?") {
                    path.append(.forgotPassword(email: AuthValidation.trimmed(email)))
                }
                Button("Create an Account") {
                    path = [.signUp]
                }
            } footer: {
                LegalLinks()
            }
        }
        .listSectionSpacing(.compact)
        .navigationTitle("Log In")
        .disabled(isLoading)
        .onAppear { if email.isEmpty { focus = .email } }
        .animation(.default, value: errorMessage)
        .animation(.default, value: showValidation)
    }

    private func logIn() {
        showValidation = true
        guard AuthValidation.emailError(email) == nil, !password.isEmpty, !isLoading, !isRateLimited else { return }
        errorMessage = nil
        notice = nil
        isLoading = true
        Task {
            defer { isLoading = false }
            do throws(APIError) {
                try await session.logIn(email: AuthValidation.trimmed(email), password: password)
            } catch {
                errorMessage = error.code == .invalidCredentials
                    ? String(localized: "Wrong email or password.", bundle: .app)
                    : error.userMessage
                if error.isRateLimited { lockUntilRetry(after: error.retryAfter ?? 60) }
            }
        }
    }
}

extension LoginView {
    /// The server refuses logins until `Retry-After` passes, so trying earlier would only extend the wait.
    private func lockUntilRetry(after seconds: TimeInterval) {
        isRateLimited = true
        Task {
            try? await Task.sleep(for: .seconds(seconds))
            isRateLimited = false
            errorMessage = nil
        }
    }
}

#Preview {
    NavigationStack {
        LoginView(path: .constant([]), notice: .constant(nil))
    }
    .environment(AuthSession(client: APIClient(tokenStore: InMemoryTokenStore())))
}
