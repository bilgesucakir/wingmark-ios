import SwiftUI

struct AppIconView: View {
    @Environment(AuthSession.self) private var session
    @AppStorage(AppLanguage.storageKey) private var language = AppLanguage.current

    @State private var picker = AppIconPicker()

    var body: some View {
        Form {
            ForEach(picker.rows) { row in
                Section {
                    Button { picker.choose(row) } label: {
                        AppIconRow(name: name(of: row), isCurrent: picker.isCurrent(row))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(picker.isCurrent(row) ? [.isSelected] : [])
                    Button { picker.choose(row) } label: {
                        AppIconShowcase(iconName: row.iconName)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHidden(true)
                } footer: {
                    if row.id == picker.rows.last?.id { footer }
                }
            }
        }
        .listSectionSpacing(.compact)
        .navigationTitle("App Icon")
        .task { await picker.load(using: session.client) }
        .alert(
            title(for: picker.pending),
            isPresented: Binding(get: { picker.pending != nil }, set: { if !$0 { picker.pending = nil } }),
            presenting: picker.pending
        ) { row in
            Button("Cancel", role: .cancel) {}
            Button("Change Icon") { Task { await picker.confirm(row) } }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            FieldError(message: picker.errorMessage)
            Text("Every icon has a default, a dark and a tinted look. To switch the Home Screen between Light, Dark, Clear and Tinted, press and hold the Home Screen, then tap Edit and Customize.")
        }
    }

    private func name(of row: AppIconPicker.Row) -> String {
        switch row.kind {
        case .standard: String(localized: "Default", bundle: .app)
        case .listed(let option): option.name(language: language)
        case .unlisted: String(localized: "Current Icon", bundle: .app)
        }
    }

    private func title(for row: AppIconPicker.Row?) -> String {
        guard let row else { return "" }
        if row.iconName == nil { return String(localized: "Switch back to the default icon?", bundle: .app) }
        return String(localized: "Switch to the \(name(of: row)) icon?", bundle: .app)
    }
}

private struct AppIconRow: View {
    let name: String
    let isCurrent: Bool

    var body: some View {
        HStack {
            Text(name)
                .foregroundStyle(.primary)
            Spacer()
            if isCurrent {
                Image(systemName: "checkmark")
                    .foregroundStyle(.tint)
                    .accessibilityLabel(Text("Current"))
            }
        }
        .contentShape(.rect)
    }
}

/// Shows the default, dark and clear looks. It is part of the card, so tapping it picks the icon too.
private struct AppIconShowcase: View {
    let iconName: String?

    @ScaledMetric(relativeTo: .body) private var size = 88.0

    var body: some View {
        HStack(spacing: 16) {
            thumbnail("IconPreview")
            thumbnail("IconPreviewDark")
            thumbnail("IconPreviewClear")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .contentShape(.rect)
    }

    private func thumbnail(_ prefix: String) -> some View {
        preview(prefix)
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: size)
            .clipShape(.rect(cornerRadius: size * 0.225, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: size * 0.225, style: .continuous).strokeBorder(.quaternary) }
    }

    @ViewBuilder private func preview(_ prefix: String) -> some View {
        if let image = UIImage(named: "\(prefix)-\(iconName ?? "AppIcon")") {
            Image(uiImage: image).resizable().scaledToFit()
        } else {
            Image(systemName: "app.fill").resizable().scaledToFit().foregroundStyle(.secondary)
        }
    }
}
