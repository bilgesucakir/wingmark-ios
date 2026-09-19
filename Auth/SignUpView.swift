import SwiftUI

struct SignUpView: View {
    @Environment(AuthSession.self) private var session
    @State private var username = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var password = ""
    @Binding var showSignUp: Bool

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            FlowingTitle(text: "Join Wingmark")

            VStack(spacing: 12) {
                TextField("Username", text: $username)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                HStack(spacing: 12) {
                    TextField("First Name", text: $firstName)
                        .textContentType(.givenName)
                    TextField("Last Name", text: $lastName)
                        .textContentType(.familyName)
                }
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("Password", text: $password)
                    .textContentType(.newPassword)
            }
            .textFieldStyle(.roundedBorder)
            .padding(.horizontal, 32)
            .padding(.top, 8)

            Text("Username: 3-30 characters. Password: at least 8 characters with a letter and a number.")
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if let errorMessage = session.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button {
                Task {
                    await session.register(
                        username: username,
                        firstName: firstName,
                        lastName: lastName,
                        email: email,
                        password: password
                    )
                }
            } label: {
                if session.isBusy {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Sign Up")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .padding(.horizontal, 32)
            .padding(.top, 4)
            .disabled(session.isBusy)

            Button("Already have an account? Log In") {
                showSignUp = false
            }
            .font(.footnote)
            .foregroundStyle(Theme.textSecondary)
            .padding(.top, 4)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Theme.background)
    }
}

#Preview {
    SignUpView(showSignUp: .constant(true))
        .environment(AuthSession())
}
