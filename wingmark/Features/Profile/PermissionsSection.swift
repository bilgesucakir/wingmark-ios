import SwiftUI

/// Settings > Permissions: where each permission stands, with Open Settings only when it is off. It doesn't
/// repeat the system's switches; iOS Settings stays the one place to change them.
struct PermissionsSection: View {
    var client: PermissionClient = .live

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @State private var states: [PermissionKind: PermissionState] = [:]

    var body: some View {
        Section {
            ForEach(PermissionKind.allCases) { kind in
                row(kind, state: states[kind] ?? client.state(kind))
            }
        } header: {
            Text("Permissions")
        } footer: {
            Text("Wingmark asks the first time you use a feature. You can change these in the Settings app.")
        }
        .onAppear(perform: refresh)
        // The person may have changed one in the Settings app and come back.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refresh() }
        }
    }

    @ViewBuilder
    private func row(_ kind: PermissionKind, state: PermissionState) -> some View {
        if state.offersSettings {
            VStack(alignment: .leading, spacing: 8) {
                header(kind, state: state)
                Text(kind.reason)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .buttonStyle(.borderless)
                .font(.footnote.weight(.semibold))
            }
        } else {
            header(kind, state: state)
        }
    }

    private func header(_ kind: PermissionKind, state: PermissionState) -> some View {
        LabeledContent {
            Text(state.title)
        } label: {
            Label(kind.title, systemImage: kind.symbol)
        }
    }

    private func refresh() {
        states = Dictionary(uniqueKeysWithValues: PermissionKind.allCases.map { ($0, client.state($0)) })
    }
}
