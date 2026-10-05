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
            if remaining > 0 && !isLoading {
                // Plain gray text: a disabled button fades its label until it can hardly be read.
                Text("Resend in \(remaining) s")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            } else {
                Button(action: action) {
                    if isLoading {
                        ProgressView()
                    } else {
                        Text(title)
                    }
                }
                .disabled(isLoading)
            }
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
            row("10–72 characters", state: rules.state(isMet: rules.hasValidLength))
            row("At least one letter and one number", state: rules.state(isMet: rules.hasLetterAndDigit))
            row("Doesn't include your email or username", state: rules.state(isMet: rules.avoidsPersonalInfo))
        }
        .font(.footnote)
    }

    /// Neutral dot until the person types; then a gray check once met, or a red cross until then. The mark, not just
    /// the color, carries the state, and VoiceOver says "Met" / "Not met". The red is darker in light mode for contrast.
    private func row(_ title: LocalizedStringKey, state: PasswordRuleState) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: symbol(for: state))
                .font(.caption2.weight(.bold))
                .frame(width: 14)
                .accessibilityHidden(true)
            Text(title)
        }
        .foregroundStyle(state == .unmet ? AnyShapeStyle(Color("UnmetRule")) : AnyShapeStyle(.secondary))
        .accessibilityElement(children: .combine)
        .accessibilityValue(
            state == .neutral ? Text(verbatim: "") : (state == .met ? Text("Met") : Text("Not met"))
        )
    }

    private func symbol(for state: PasswordRuleState) -> String {
        switch state {
        case .neutral: "circle.fill"
        case .met: "checkmark"
        case .unmet: "xmark"
        }
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

/// A link row for a legal document. The icon trails the title so the row's divider lines up with the toggle below it.
struct LegalDocumentLink: View {
    let title: String
    let url: URL

    var body: some View {
        Link(destination: url) {
            HStack {
                Text(title)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
    }
}

/// For each legal document: its link and an "I accept" switch. Shared by sign-up and the "Our Terms Changed" screen.
struct ConsentRows: View {
    let types: [ConsentType]
    let documents: LegalDocuments
    @Binding var accepted: Set<ConsentType>

    var body: some View {
        ForEach(types, id: \.self) { type in
            if let url = documents.url(of: type) {
                LegalDocumentLink(title: type.title, url: url)
            }
            Toggle(documents.acceptanceLabel(of: type), isOn: Binding(
                get: { accepted.contains(type) },
                set: { if $0 { accepted.insert(type) } else { accepted.remove(type) } }
            ))
        }
    }
}
