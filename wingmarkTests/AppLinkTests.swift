import Foundation
import Testing
import UIKit
@testable import wingmark

@MainActor
struct AppLinkTests {
    private let id = UUID(uuidString: "3F2504E0-4F89-11D3-9A0C-0305E82C3301")!

    @Test func everyLinkSurvivesAURLRoundTrip() {
        for link in [AppLink.logSighting, .badges, .guide, .sighting(id)] {
            #expect(AppLink(url: link.url) == link)
        }
        #expect(AppLink.sighting(id).url.absoluteString == "wingmark://sighting/3f2504e0-4f89-11d3-9a0c-0305e82c3301")
    }

    @Test func ignoresForeignOrMalformedURLs() {
        for text in ["https://example.com/log", "wingmark://unknown", "wingmark://sighting", "wingmark://sighting/not-a-uuid",
                     "wingmark://log/extra"] {
            #expect(AppLink(url: URL(string: text)!) == nil, "\(text) should not open anything")
        }
    }

    @Test func theQuickActionOpensLogSightingAndOthersAreIgnored() {
        let router = AppRouter()
        let item = UIApplicationShortcutItem(type: QuickAction.logSightingType, localizedTitle: "x")
        #expect(QuickAction.handle(item, router: router))
        #expect(router.pending == .logSighting)

        let other = AppRouter()
        #expect(!QuickAction.handle(UIApplicationShortcutItem(type: "other", localizedTitle: "x"), router: other))
        #expect(other.pending == nil)
    }

    @Test func theURLSchemeIsRegistered() throws {
        let types = try #require(Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]])
        let schemes = types.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
        #expect(schemes.contains(AppLink.scheme))
    }
}
