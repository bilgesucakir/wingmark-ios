import Foundation
import Testing

struct TransportSecurityTests {
    private func plist(_ name: String) throws -> [String: Any] {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appending(path: "Config/\(name)"))
        return try #require(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
    }

    @Test func releaseHasNoAppTransportSecurityException() throws {
        #expect(try plist("Info.plist")["NSAppTransportSecurity"] == nil)
    }

    @Test func onlyDebugAllowsLocalNetworking() throws {
        let ats = try #require(try plist("Info-Debug.plist")["NSAppTransportSecurity"] as? [String: Any])
        #expect(ats["NSAllowsLocalNetworking"] as? Bool == true)
        #expect(ats["NSAllowsArbitraryLoads"] == nil)
    }

    @Test func bothKeepTheBaseURLSetting() throws {
        for name in ["Info.plist", "Info-Debug.plist"] {
            #expect(try plist(name)["WingmarkAPIBaseURL"] as? String == "$(WINGMARK_API_BASE_URL)")
        }
    }
}
