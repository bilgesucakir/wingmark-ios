import SwiftUI

/// Mirrors wingmark-backend's UnitPreference enum.
enum UnitPreference: String, CaseIterable, Identifiable {
    case metric = "METRIC"
    case imperial = "IMPERIAL"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .metric: "Metric (km, m)"
        case .imperial: "Imperial (mi, ft)"
        }
    }
}

struct SettingsView: View {
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.system.rawValue
    @AppStorage("unitPreference") private var unitPreferenceRaw = UnitPreference.metric.rawValue

    private var appLanguage: Binding<AppLanguage> {
        Binding(
            get: { AppLanguage(rawValue: appLanguageRaw) ?? .system },
            set: { appLanguageRaw = $0.rawValue }
        )
    }

    private var unitPreference: Binding<UnitPreference> {
        Binding(
            get: { UnitPreference(rawValue: unitPreferenceRaw) ?? .metric },
            set: { unitPreferenceRaw = $0.rawValue }
        )
    }

    var body: some View {
        Form {
            Section {
                Picker("Language", selection: appLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
            } footer: {
                Text("Changes take effect immediately.")
            }

            Section("Units") {
                Picker("Distance", selection: unitPreference) {
                    ForEach(UnitPreference.allCases) { unit in
                        Text(unit.label).tag(unit)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .toolbar {
            ToolbarItem(placement: .principal) {
                FlowingTitle(text: "Settings")
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
