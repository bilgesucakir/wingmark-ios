import SwiftUI

struct AboutView: View {
    @Environment(AuthSession.self) private var session
    @State private var legal: LegalDocuments?

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "–"
        let build = info?["CFBundleVersion"] as? String ?? "–"
        return "\(short) (\(build))"
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("Version", value: version)
                LabeledContent("Developer", value: AppConfig.developerName)
                if let mail = URL(string: "mailto:\(AppConfig.supportEmail)"), AppConfig.supportEmail.contains("@") {
                    Link(destination: mail) {
                        Label("Contact Support", systemImage: "envelope")
                    }
                } else {
                    LabeledContent("Support", value: AppConfig.supportEmail)
                }
            }

            Section("Legal") {
                legalRow(.privacy)
                if let url = legal?.url(of: .terms) {
                    Link(destination: url) { Label(ConsentType.terms.title, systemImage: "doc.text") }
                } else {
                    Link(destination: AppConfig.appleStandardEULA) {
                        Label("Terms of Use (Apple Standard EULA)", systemImage: "doc.text")
                    }
                }
            }

            Section {
                NavigationLink("Acknowledgements") { AcknowledgementsView() }
            }
        }
        .navigationTitle("About")
        .task { legal = try? await session.legalDocuments() }
    }

    @ViewBuilder
    private func legalRow(_ type: ConsentType) -> some View {
        if let url = legal?.url(of: type) {
            Link(destination: url) { Label(type.title, systemImage: "hand.raised") }
        } else {
            LabeledContent(type.title) { Text("Not available yet") }
        }
    }
}

struct AcknowledgementsView: View {
    var body: some View {
        Form {
            Section {
                Text("Bird recordings come from xeno-canto. Each one is shared by its recordist under a Creative Commons license, shown next to the recording in the Guide.")
                Link("xeno-canto.org", destination: URL(string: "https://xeno-canto.org")!)
            } header: {
                Text("Bird Sounds")
            }
            Section {
                Text("Some species photos come from iNaturalist contributors under Creative Commons licenses. The photographer and license appear under each photo in the Guide.")
                Link("inaturalist.org", destination: URL(string: "https://www.inaturalist.org")!)
            } header: {
                Text("Species Photos")
            }
            Section {
                Text("Maps and place names are provided by Apple Maps. Icons are SF Symbols by Apple.")
            } header: {
                Text("Maps and Icons")
            }
        }
        .navigationTitle("Acknowledgements")
    }
}
