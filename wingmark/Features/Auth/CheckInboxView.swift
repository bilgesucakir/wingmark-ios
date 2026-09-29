import SwiftUI

struct CheckInboxView: View {
    @Environment(AuthSession.self) private var session
    let email: String

    @State private var resendAvailableAt = Date.now.addingTimeInterval(30)
    @State private var isResending = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "envelope.badge")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                VStack(spacing: 8) {
                    Text("Check Your Inbox")
                        .font(.title.bold())
                    Text("We sent a verification link to **\(email)**. Open it to activate your account, then log in.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                if let message {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                Spacer()
                VStack(spacing: 12) {
                    Button {
                        session.showLogin()
                    } label: {
                        Text("Go to Login").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    CooldownButton(
                        title: "Resend Email", availableAt: resendAvailableAt, isLoading: isResending, action: resend
                    )
                }
            }
            .padding(24)
        }
    }

    private func resend() {
        isResending = true
        message = nil
        Task {
            defer { isResending = false }
            do throws(APIError) {
                try await session.resendVerificationEmail(to: email)
                message = String(localized: "Email sent. It can take a minute to arrive; check your spam folder too.")
                resendAvailableAt = .now.addingTimeInterval(30)
            } catch {
                message = error.userMessage
            }
        }
    }
}

#Preview {
    CheckInboxView(email: "ada@example.com")
        .environment(AuthSession(client: APIClient(tokenStore: InMemoryTokenStore())))
}
