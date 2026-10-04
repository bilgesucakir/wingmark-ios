import SwiftUI

struct ForgotPasswordView: View {
    @Environment(AuthSession.self) private var session
    @Binding var path: [AuthRoute]

    @State private var email: String
    @State private var showValidation = false
    @State private var errorMessage: String?
    @State private var isLoading = false
    @FocusState private var isFocused: Bool

    init(path: Binding<[AuthRoute]>, initialEmail: String) {
        _path = path
        _email = State(initialValue: initialEmail)
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    TextField("Email", text: $email)
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($isFocused)
                        .submitLabel(.send)
                        .onSubmit(sendCode)
                    FieldError(message: showValidation ? AuthValidation.emailError(email) : nil)
                }
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Enter the email you signed up with and we'll send you a 6-digit code to reset your password.")
                    FieldError(message: errorMessage)
                }
            }

            Section {
                PrimaryActionButton(title: "Send Code", isLoading: isLoading, action: sendCode)
                    .disabled(email.isEmpty || isLoading)
            }
        }
        .navigationTitle("Reset Password")
        .disabled(isLoading)
        .onAppear { isFocused = true }
    }

    private func sendCode() {
        showValidation = true
        guard AuthValidation.emailError(email) == nil, !isLoading else { return }
        let email = AuthValidation.trimmed(email)
        errorMessage = nil
        isLoading = true
        Task {
            defer { isLoading = false }
            do throws(APIError) {
                try await session.requestPasswordReset(email: email)
                path.append(.resetPassword(email: email))
            } catch {
                errorMessage = error.userMessage
            }
        }
    }
}

struct ResetPasswordView: View {
    @Environment(AuthSession.self) private var session
    let email: String
    let onReset: () -> Void

    @State private var code = ""
    @State private var password = ""
    @State private var confirmation = ""
    @State private var showValidation = false
    @State private var codeError: String?
    @State private var passwordServerError: String?
    @State private var errorMessage: String?
    @State private var codeIsDead = false
    @State private var isLoading = false
    @State private var isResending = false
    @State private var resendAvailableAt = Date.now.addingTimeInterval(60)
    @FocusState private var focus: Field?

    private enum Field { case code, password, confirmation }

    private var rules: PasswordRules { PasswordRules(password: password, email: email) }

    private var isValid: Bool {
        AuthValidation.isValidCode(code)
            && rules.isSatisfied
            && AuthValidation.confirmationError(password, confirmation) == nil
    }

    var body: some View {
        Form {
            Section {
                VStack(spacing: 6) {
                    OneTimeCodeField(code: $code)
                        .focused($focus, equals: .code)
                    FieldError(message: codeError)
                }
            } header: {
                Text("If an account exists for \(email), we sent a 6-digit code. It expires in 15 minutes.")
                    .textCase(nil)
            } footer: {
                HStack {
                    if codeIsDead {
                        Text("Request a new code to try again.")
                    }
                    Spacer()
                    CooldownButton(
                        title: "Send New Code", availableAt: resendAvailableAt, isLoading: isResending, action: resend
                    )
                    .font(.footnote)
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 6) {
                    SecureField("New Password", text: $password)
                        .textContentType(.newPassword)
                        .focused($focus, equals: .password)
                        .submitLabel(.next)
                        .onSubmit { focus = .confirmation }
                    FieldError(message: passwordServerError
                        ?? (showValidation ? AuthValidation.passwordError(password, email: email) : nil))
                }
                VStack(alignment: .leading, spacing: 6) {
                    SecureField("Confirm New Password", text: $confirmation)
                        .textContentType(.newPassword)
                        .focused($focus, equals: .confirmation)
                        .submitLabel(.done)
                        .onSubmit(reset)
                    FieldError(message: showValidation ? AuthValidation.confirmationError(password, confirmation) : nil)
                }
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    PasswordRequirements(rules: rules)
                    FieldError(message: errorMessage)
                }
            }

            Section {
                PrimaryActionButton(title: "Reset Password", isLoading: isLoading, action: reset)
                    .disabled(code.count < 6 || !rules.isSatisfied || confirmation.isEmpty || isLoading)
            }
        }
        .navigationTitle("Enter Code")
        .disabled(isLoading)
        .onAppear { focus = .code }
        .onChange(of: code) { codeError = nil }
        .onChange(of: password) { passwordServerError = nil }
        .animation(.default, value: codeError)
        .animation(.default, value: showValidation)
    }

    private func reset() {
        showValidation = true
        guard isValid, !isLoading else { return }
        errorMessage = nil
        isLoading = true
        Task {
            defer { isLoading = false }
            do throws(APIError) {
                try await session.resetPassword(email: email, code: code, newPassword: password)
                onReset()
            } catch {
                switch error.code {
                case .invalidOrExpiredCode:
                    codeError = String(localized: "The code is wrong or has expired.", bundle: .app)
                    codeIsDead = true
                case .samePassword:
                    passwordServerError = String(localized: "Choose a different password than your current one.", bundle: .app)
                case .weakPassword, .passwordBreached:
                    passwordServerError = error.userMessage
                case .validationFailed:
                    let fields = error.validationErrors
                    if fields["code"] != nil { codeError = AuthValidation.serverFieldMessage(for: "code") }
                    if fields["newPassword"] != nil {
                        passwordServerError = AuthValidation.serverFieldMessage(for: "newPassword")
                    }
                default:
                    errorMessage = error.userMessage
                }
            }
        }
    }

    private func resend() {
        isResending = true
        Task {
            defer { isResending = false }
            do throws(APIError) {
                try await session.requestPasswordReset(email: email)
                code = ""
                codeError = nil
                codeIsDead = false
                resendAvailableAt = .now.addingTimeInterval(60)
                focus = .code
            } catch {
                errorMessage = error.userMessage
            }
        }
    }
}

#Preview {
    NavigationStack {
        ResetPasswordView(email: "ada@example.com") {}
    }
    .environment(AuthSession(client: APIClient(tokenStore: InMemoryTokenStore())))
}
