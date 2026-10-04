import SafariServices
import SwiftUI

struct WebPage: Identifiable {
    let url: URL
    var id: URL { url }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

extension URL {
    /// Web pages open in the in-app browser; mailto:, app-settings: and the like go to the system.
    var opensInApp: Bool { ["http", "https"].contains(scheme?.lowercased()) }
}

private struct InAppLinks: ViewModifier {
    @State private var page: WebPage?

    func body(content: Content) -> some View {
        content
            .environment(\.openURL, OpenURLAction { url in
                guard url.opensInApp else { return .systemAction }
                page = WebPage(url: url)
                return .handled
            })
            .sheet(item: $page) { page in
                SafariView(url: page.url).ignoresSafeArea()
            }
    }
}

extension View {
    /// Opens web links (Privacy Policy and the like) in a Safari sheet over the app instead of leaving it.
    func opensLinksInApp() -> some View {
        modifier(InAppLinks())
    }
}
