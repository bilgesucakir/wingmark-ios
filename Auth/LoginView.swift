import SwiftUI

struct LoginView: View {
    @Environment(AuthSession.self) private var session
    @State private var email = ""
    @State private var password = ""
    @Binding var showSignUp: Bool

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            FlowingTitle(text: "Wingmark")

            VStack(spacing: 12) {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("Password", text: $password)
                    .textContentType(.password)
            }
            .textFieldStyle(.roundedBorder)
            .padding(.horizontal, 32)
            .padding(.top, 8)

            if let errorMessage = session.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button {
                Task { await session.login(email: email, password: password) }
            } label: {
                if session.isBusy {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Log In")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .padding(.horizontal, 32)
            .padding(.top, 4)
            .disabled(session.isBusy)

            Button("Don't have an account? Sign Up") {
                showSignUp = true
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
    LoginView(showSignUp: .constant(false))
        .environment(AuthSession())
}
