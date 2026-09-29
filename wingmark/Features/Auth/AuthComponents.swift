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
