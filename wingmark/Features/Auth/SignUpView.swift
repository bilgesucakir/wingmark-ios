import SwiftUI

struct SignUpView: View {
    @Environment(AuthSession.self) private var session
    @Binding var path: [AuthRoute]

    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var showValidation = false
    @State private var serverErrors: [String: String] = [:]
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var legal = LegalDocuments.unpublished
    @State private var accepted: Set<ConsentType> = []
    @FocusState private var focus: Field?

    private enum Field { case username, email, password, firstName, lastName }

    private func error(for field: String, client: String?) -> String? {
        serverErrors[field] ?? (showValidation ? client : nil)
    }

    private var rules: PasswordRules { PasswordRules(password: password, email: email, username: username) }

    private var isValid: Bool {
        AuthValidation.usernameError(username) == nil
            && AuthValidation.emailError(email) == nil
            && rules.isSatisfied
    }

    private var acceptedAll: Bool { Set(legal.published).isSubset(of: accepted) }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    TextField("Username", text: $username)
                        .textContentType(.nickname)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focus, equals: .username)
                        .submitLabel(.next)
                        .onSubmit { focus = .email }
                    FieldError(message: error(for: "username", client: AuthValidation.usernameError(username)))
                }
                VStack(alignment: .leading, spacing: 6) {
                    TextField("Email", text: $email)
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focus, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { focus = .password }
                    FieldError(message: error(for: "email", client: AuthValidation.emailError(email)))
                }
                VStack(alignment: .leading, spacing: 6) {
                    SecureField("Password", text: $password)
                        .textContentType(.newPassword)
                        .focused($focus, equals: .password)
                        .submitLabel(.next)
                        .onSubmit { focus = .firstName }
                    FieldError(message: error(for: "password", client: AuthValidation.passwordError(password, email: email, username: username)))
                    PasswordRequirements(rules: rules)
                }
            }

            Section("Name (Optional)") {
                TextField("First Name", text: $firstName)
                    .textContentType(.givenName)
                    .focused($focus, equals: .firstName)
                    .submitLabel(.next)
                    .onSubmit { focus = .lastName }
                TextField("Last Name", text: $lastName)
                    .textContentType(.familyName)
                    .focused($focus, equals: .lastName)
                    .submitLabel(.join)
                    .onSubmit(signUp)
            }

            if !legal.published.isEmpty {
                Section {
                    ForEach(legal.published, id: \.self) { type in
                        if let url = legal.url(of: type) {
                            Link(destination: url) {
                                Label(type.title, systemImage: "doc.text")
                            }
                        }
                        Toggle(type.acceptanceLabel, isOn: Binding(
                            get: { accepted.contains(type) },
                            set: { if $0 { accepted.insert(type) } else { accepted.remove(type) } }
                        ))
                    }
                }
            }

            Section {
                PrimaryActionButton(title: "Create Account", isLoading: isLoading, action: signUp)
                    .disabled(username.isEmpty || email.isEmpty || !rules.isSatisfied || !acceptedAll || isLoading)
            } footer: {
                FieldError(message: errorMessage)
            }

            Section {
                Button("Already have an account? Log In") {
                    path = [.login]
                }
            }
        }
        .navigationTitle("Create Account")
        .disabled(isLoading)
        .onAppear { focus = .username }
        .task { await loadLegal() }
        .onChange(of: username) { serverErrors["username"] = nil }
        .onChange(of: email) { serverErrors["email"] = nil }
        .onChange(of: password) { serverErrors["password"] = nil }
        .animation(.default, value: showValidation)
        .animation(.default, value: serverErrors)
    }

    private func loadLegal() async {
        if let documents = try? await session.legalDocuments() {
            legal = documents
            accepted.formIntersection(documents.published)
        }
    }

    private func signUp() {
        showValidation = true
        guard isValid, acceptedAll, !isLoading else { return }
        errorMessage = nil
        isLoading = true
        let first = AuthValidation.trimmed(firstName)
        let last = AuthValidation.trimmed(lastName)
        let request = AuthAPI.RegisterRequest(
            email: AuthValidation.trimmed(email),
            password: password,
            username: AuthValidation.trimmed(username),
            firstName: first.isEmpty ? nil : first,
            lastName: last.isEmpty ? nil : last,
            acceptedTermsVersion: accepted.contains(.terms) ? legal.termsVersion : nil,
            acceptedPrivacyVersion: accepted.contains(.privacy) ? legal.privacyVersion : nil
        )
        Task {
            defer { isLoading = false }
            do throws(APIError) {
                try await session.register(request)
            } catch {
                switch error.code {
                case .emailTaken:
                    serverErrors["email"] = String(localized: "An account with this email already exists.", bundle: .app)
                case .usernameTaken:
                    serverErrors["username"] = String(localized: "This username is already taken.", bundle: .app)
                case .validationFailed:
                    serverErrors = AuthValidation.serverFieldErrors(error)
                case .weakPassword, .passwordBreached:
                    serverErrors["password"] = error.userMessage
                case .termsNotAccepted, .privacyNotAccepted:
                    // The documents changed since this screen loaded, so ask again for the new versions.
                    accepted = []
                    await loadLegal()
                    errorMessage = error.userMessage
                default:
                    errorMessage = error.userMessage
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SignUpView(path: .constant([]))
    }
    .environment(AuthSession(client: APIClient(tokenStore: InMemoryTokenStore())))
}
