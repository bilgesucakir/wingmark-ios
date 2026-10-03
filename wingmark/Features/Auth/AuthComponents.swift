import SwiftUI

struct FieldError: View {
    let message: String?

    var body: some View {
        if let message {
            Label(message, systemImage: "exclamationmark.circle.fill")
                .font(.footnote)
                .foregroundStyle(.red)
                .transition(.opacity)
        }
    }
}

struct PrimaryActionButton: View {
    let title: LocalizedStringKey
    var isLoading = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(title).opacity(isLoading ? 0 : 1)
                if isLoading { ProgressView() }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }
}

/// A button that stays disabled until `availableAt`, showing the remaining seconds.
struct CooldownButton: View {
    let title: LocalizedStringKey
    let availableAt: Date
    var isLoading = false
    let action: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = Int(availableAt.timeIntervalSince(context.date).rounded(.up))
            Button(action: action) {
                if isLoading {
                    ProgressView()
                } else if remaining > 0 {
                    Text("Resend in \(remaining) s")
                        .monospacedDigit()
                } else {
                    Text(title)
                }
            }
            .disabled(remaining > 0 || isLoading)
        }
    }
}

struct OneTimeCodeField: View {
    @Binding var code: String

    var body: some View {
        TextField("000000", text: $code)
            .textContentType(.oneTimeCode)
            .keyboardType(.numberPad)
            .font(.system(.title, design: .monospaced).weight(.semibold))
            .kerning(8)
            .multilineTextAlignment(.center)
            .accessibilityLabel(Text("6-digit code"))
            .onChange(of: code) { _, newValue in
                let digits = String(newValue.filter { $0.isASCII && $0.isNumber }.prefix(6))
                if digits != newValue { code = digits }
            }
    }
}

/// Live checklist of the password rules, shown under new-password fields.
struct PasswordRequirements: View {
    let rules: PasswordRules

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            row("10–72 characters", met: rules.hasValidLength)
            row("At least one letter and one number", met: rules.hasLetterAndDigit)
            row("Doesn't include your email or username", met: rules.avoidsPersonalInfo)
        }
        .font(.footnote)
    }

    private func row(_ title: LocalizedStringKey, met: Bool) -> some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: met ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(met ? AnyShapeStyle(.green) : AnyShapeStyle(.secondary))
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(met ? Text("Met") : Text("Not met"))
    }
}

/// Privacy Policy and Terms links for the signed-out screens (Guideline 5.1.1(i)); hidden until a document is published.
struct LegalLinks: View {
    @Environment(AuthSession.self) private var session
    @State private var legal = LegalDocuments.unpublished

    var body: some View {
        HStack(spacing: 16) {
            ForEach(ConsentType.allCases.reversed(), id: \.self) { type in
                if let url = legal.url(of: type) {
                    Link(type.title, destination: url)
                }
            }
        }
        .font(.footnote)
        .task { if let documents = try? await session.legalDocuments() { legal = documents } }
    }
}
