import Foundation
import Testing
@testable import wingmark

@MainActor
struct AppIconTests {
    private let halloween = AppIconOption(iconId: "halloween", nameEn: "Halloween", nameTr: "Cadılar Bayramı")
    private let newyears = AppIconOption(iconId: "newyears", nameEn: "New Year", nameTr: "Yılbaşı")

    private final class Store {
        var name: String?
        var fails = false
        init(_ name: String? = nil) { self.name = name }
    }

    private func picker(current: String? = nil, bundled: Set<String> = ["halloween", "newyears"], store: Store? = nil) -> AppIconPicker {
        let store = store ?? Store(current)
        return AppIconPicker(
            bundled: bundled,
            switcher: AppIconSwitcher(
                current: { store.name },
                set: { name in
                    if store.fails { throw URLError(.cannotConnectToHost) }
                    store.name = name
                }
            )
        )
    }

    private func client(reply: MockTransport.Reply) -> APIClient {
        let transport = MockTransport { _ in reply }
        return APIClient(baseURL: URL(string: "https://api.test")!, tokenStore: InMemoryTokenStore(Fixtures.tokens("1")), transport: transport)
    }

    @Test func decodesTheListAndFollowsTheAppLanguage() throws {
        let json = #"[{"iconId":"halloween","nameEn":"Halloween","nameTr":"Cadılar Bayramı"}]"#
        let options = try JSONCoding.makeDecoder().decode([AppIconOption].self, from: Data(json.utf8))
        #expect(options == [halloween])
        #expect(halloween.name(language: .english) == "Halloween")
        #expect(halloween.name(language: .turkish) == "Cadılar Bayramı")
    }

    @Test func ignoresIdsThisBuildDoesNotContainAndRepeats() {
        let unknown = AppIconOption(iconId: "easter", nameEn: "Easter", nameTr: "Paskalya")
        let result = AppIconPicker.available([halloween, unknown, halloween, newyears], bundled: ["halloween", "newyears"])
        #expect(result == [halloween, newyears])
    }

    @Test func readsTheBundledIconsFromTheInfoPlist() {
        let info: [String: Any] = ["CFBundleIcons": ["CFBundleAlternateIcons": ["halloween": [:], "newyears": [:]]]]
        #expect(BundledAppIcons.ids(in: info) == ["halloween", "newyears"])
        #expect(BundledAppIcons.ids(in: [:]).isEmpty)
    }

    @Test func thisBuildContainsTheSeasonalIcons() {
        #expect(BundledAppIcons.ids().isSuperset(of: ["halloween", "newyears", "valentines"]))
    }

    @Test func listsTheBackendIconsAfterTheDefault() async {
        let body = #"[{"iconId":"halloween","nameEn":"Halloween","nameTr":"x"},{"iconId":"easter","nameEn":"Easter","nameTr":"y"}]"#
        let picker = picker()
        await picker.load(using: client(reply: .init(status: 200, body: body)))
        #expect(picker.rows.map(\.iconName) == [nil, "halloween"])
        #expect(picker.isCurrent(picker.rows[0]))
    }

    @Test func aFailedRequestShowsOnlyTheDefault() async {
        let picker = picker()
        await picker.load(using: client(reply: Fixtures.error(status: 500, code: "internal_error")))
        #expect(picker.rows.map(\.iconName) == [nil])
    }

    @Test func aRemovedIconStaysSelectedAndTheDefaultStaysOffered() async {
        let picker = picker(current: "halloween")
        await picker.load(using: client(reply: .init(status: 200, body: "[]")))
        #expect(picker.rows.map(\.iconName) == [nil, "halloween"])
        #expect(picker.rows[1].kind == .unlisted)
        #expect(picker.isCurrent(picker.rows[1]))
        #expect(!picker.isCurrent(picker.rows[0]))
    }

    @Test func choosingAnIconAsksFirstAndChangesOnlyAfterConfirming() async {
        let store = Store()
        let picker = picker(store: store)
        await picker.load(using: client(reply: .init(status: 200, body: #"[{"iconId":"halloween","nameEn":"H","nameTr":"H"}]"#)))
        let row = picker.rows[1]
        picker.choose(row)
        #expect(picker.pending == row)
        #expect(store.name == nil)
        await picker.confirm(row)
        #expect(store.name == "halloween")
        #expect(picker.pending == nil)
        #expect(picker.isCurrent(row))
    }

    @Test func choosingTheDefaultResetsTheIcon() async {
        let store = Store("halloween")
        let picker = picker(store: store)
        await picker.load(using: client(reply: .init(status: 200, body: "[]")))
        let standard = picker.rows[0]
        picker.choose(standard)
        await picker.confirm(standard)
        #expect(store.name == nil)
        #expect(picker.isCurrent(standard))
    }

    @Test func choosingTheCurrentIconDoesNothing() {
        let picker = picker(current: "halloween")
        picker.choose(AppIconPicker.Row(iconName: "halloween", kind: .unlisted))
        #expect(picker.pending == nil)
    }

    @Test func aFailedChangeKeepsTheIconAndShowsAMessage() async {
        let store = Store()
        store.fails = true
        let picker = picker(store: store)
        await picker.confirm(AppIconPicker.Row(iconName: "halloween", kind: .unlisted))
        #expect(store.name == nil)
        #expect(picker.errorMessage != nil)
    }
}
