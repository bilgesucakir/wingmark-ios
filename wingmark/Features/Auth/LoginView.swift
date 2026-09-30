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
                VStack(alignment: .leading, spacing: 6) {
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
            } footer: {
                FieldError(message: errorMessage)
            }

            Section {
                PrimaryActionButton(title: "Log In", isLoading: isLoading, action: logIn)
                    .disabled(email.isEmpty || password.isEmpty || isLoading)
            }

            Section {
                Button("Forgot Password?") {
                    path.append(.forgotPassword(email: AuthValidation.trimmed(email)))
                }
                Button("Create an Account") {
                    path = [.signUp]
                }
            }
        }
        .navigationTitle("Log In")
        .disabled(isLoading)
        .onAppear { if email.isEmpty { focus = .email } }
        .animation(.default, value: errorMessage)
        .animation(.default, value: showValidation)
    }

    private func logIn() {
        showValidation = true
        guard AuthValidation.emailError(email) == nil, !password.isEmpty, !isLoading else { return }
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
            }
        }
    }
}

#Preview {
    NavigationStack {
        LoginView(path: .constant([]), notice: .constant(nil))
    }
    .environment(AuthSession(client: APIClient(tokenStore: InMemoryTokenStore())))
}
