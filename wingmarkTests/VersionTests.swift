import Foundation
import Testing
@testable import wingmark

/// The app, its two extensions and the tests must carry the same version and build, or App Store Connect rejects the upload.
struct VersionTests {
    private func versions(of bundle: Bundle) -> (version: String?, build: String?) {
        let info = bundle.infoDictionary
        return (info?["CFBundleShortVersionString"] as? String, info?["CFBundleVersion"] as? String)
    }

    private final class Anchor {}

    @Test func everyTargetHasTheSameVersionAndBuild() throws {
        let app = Bundle.main
        let expected = versions(of: app)
        #expect(expected.version != nil && expected.build != nil)

        let plugIns = try #require(app.builtInPlugInsURL)
        let extensions = try FileManager.default.contentsOfDirectory(at: plugIns, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "appex" }
        #expect(extensions.count == 2)
        for url in extensions {
            let bundle = try #require(Bundle(url: url))
            let found = versions(of: bundle)
            #expect(found.version == expected.version, "\(url.lastPathComponent) version")
            #expect(found.build == expected.build, "\(url.lastPathComponent) build")
        }

        let tests = versions(of: Bundle(for: Anchor.self))
        #expect(tests.version == expected.version)
        #expect(tests.build == expected.build)
    }

    @Test func theBuildIsAboveTheOneInTheAppStore() throws {
        let build = try #require(Bundle.main.infoDictionary?["CFBundleVersion"] as? String).flatMap(Int.init)
        #expect((build ?? 0) > 5)
    }
}
