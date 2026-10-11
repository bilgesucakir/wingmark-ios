import Foundation
import Testing
@testable import wingmark

@MainActor
struct GuideTests {
    private func speciesJSON(_ index: Int) -> String {
        let id = String(format: "00000000-0000-0000-0000-%012d", index)
        return #"{"id":"\#(id)","commonName":{"en":"Bird \#(index)","tr":"Kuş \#(index)"},"scientificName":"Avis \#(index)","family":null,"order":null,"description":null,"lifespan":null,"diet":null,"habitat":null,"sizeDescription":null,"conservationStatus":null,"nativeRange":null,"images":[]}"#
    }

    private func pageJSON(_ indices: Range<Int>, number: Int, totalPages: Int) -> String {
        #"{"content":[\#(indices.map(speciesJSON).joined(separator: ","))],"page":{"size":30,"number":\#(number),"totalElements":45,"totalPages":\#(totalPages)}}"#
    }

    static let facetsJSON = #"{"orders":[{"value":"Passeriformes","name":"Ötücü Kuşlar","count":228},{"value":"Anseriformes","name":"Ördekler","count":40}],"families":[{"value":"Muscicapidae","order":"Passeriformes","name":"Sinekkapanlar","count":33}]}"#

    private func makeSearch(
        pause: Pause = .immediate,
        tokens: TokenPair? = nil,
        handler: @escaping (URLRequest) async throws -> MockTransport.Reply
    ) -> (SpeciesSearch, MockTransport) {
        let transport = MockTransport { request in
            // The filter menus' own request has its own answer; the tests below are about the list.
            request.url?.path == "/api/species/facets" ? .init(status: 200, body: Self.facetsJSON) : try await handler(request)
        }
        let client = APIClient(baseURL: URL(string: "https://api.test")!, tokenStore: InMemoryTokenStore(tokens),
                               transport: transport, languageCode: { "tr" })
        return (SpeciesSearch(client: client, pause: pause, canFilterBySeen: tokens != nil), transport)
    }

    /// Only the list requests, leaving out the facets ones.
    private func lists(_ transport: MockTransport) -> [URLRequest] {
        transport.requests.filter { $0.url?.path == "/api/species" }
    }

    private func facetRequests(_ transport: MockTransport) -> [URLRequest] {
        transport.requests.filter { $0.url?.path == "/api/species/facets" }
    }

    private func query(_ request: URLRequest?) -> [String: String] {
        let items = request?.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false)?.queryItems } ?? []
        return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
    }

    @Test func pagesThroughResults() async {
        let (search, transport) = makeSearch { request in
            let page = request.url?.query?.contains("page=1") == true ? 1 : 0
            return .init(status: 200, body: page == 0
                ? self.pageJSON(0..<30, number: 0, totalPages: 2)
                : self.pageJSON(30..<45, number: 1, totalPages: 2))
        }
        await search.reload()
        #expect(search.results.count == 30)
        #expect(search.hasMore)

        await search.loadMoreIfNeeded(after: search.results[5])
        #expect(lists(transport).count == 1)

        await search.loadMoreIfNeeded(after: search.results[29])
        #expect(search.results.count == 45)
        #expect(!search.hasMore)
        #expect(query(lists(transport).first)["sort"] == "commonName.tr,asc")
        #expect(lists(transport).first?.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test func sortChangeReloadsWithNewParameterWithoutWaiting() async throws {
        let gate = GatedPause()
        let (search, transport) = makeSearch(pause: gate.pause) { _ in
            .init(status: 200, body: self.pageJSON(0..<3, number: 0, totalPages: 1))
        }
        await search.reload()
        search.sort = .scientificDescending
        await search.settled()
        #expect(query(lists(transport).last)["sort"] == "scientificName,desc")
        #expect(search.results.count == 3)
        #expect(gate.requested.isEmpty, "a sort change must not be debounced")
    }

    @Test func typingIsDebouncedIntoOneRequest() async throws {
        let gate = GatedPause()
        let (search, transport) = makeSearch(pause: gate.pause) { _ in
            .init(status: 200, body: self.pageJSON(0..<1, number: 0, totalPages: 1))
        }
        search.query = "r"
        search.query = "ro"
        search.query = "rob"
        await gate.waitUntilWaiting(count: 3)

        // Every keystroke is waiting out the 300 ms pause; nothing has been sent yet.
        #expect(gate.requested == Array(repeating: .milliseconds(300), count: 3))
        #expect(lists(transport).isEmpty)

        gate.release()
        await search.settled()
        #expect(lists(transport).count == 1)
        #expect(query(lists(transport).first)["search"] == "rob")
    }

    @Test func filterReloadsFromTheFirstPageWithItsParametersAndWithoutWaiting() async throws {
        let gate = GatedPause()
        let (search, transport) = makeSearch(pause: gate.pause) { _ in
            .init(status: 200, body: self.pageJSON(0..<3, number: 0, totalPages: 1))
        }
        await search.reload()
        search.filter = SpeciesFilter(order: "Passeriformes", family: "Muscicapidae")
        await search.settled()

        let request = lists(transport).last
        #expect(query(request)["order"] == "Passeriformes")
        #expect(query(request)["family"] == "Muscicapidae")
        #expect(query(request)["page"] == "0")
        #expect(query(request)["seen"] == nil)
        #expect(request?.value(forHTTPHeaderField: "Authorization") == nil, "order and family are public")
        #expect(gate.requested.isEmpty, "a filter change must not be debounced")
    }

    @Test func seenFilterSendsTheTokenAndNothingElseDoes() async {
        let (search, transport) = makeSearch(tokens: Fixtures.tokens("a")) { _ in
            .init(status: 200, body: self.pageJSON(0..<2, number: 0, totalPages: 1))
        }
        await search.reload()
        #expect(lists(transport).last?.value(forHTTPHeaderField: "Authorization") == nil)

        search.filter.seen = .unseen
        await search.settled()
        #expect(query(lists(transport).last)["seen"] == "unseen")
        #expect(lists(transport).last?.value(forHTTPHeaderField: "Authorization") != nil)
        #expect(facetRequests(transport).last?.value(forHTTPHeaderField: "Authorization") != nil)
        #expect(search.canFilterBySeen)
    }

    @Test func facetsFollowTheSearchAndFilterAndAreNotRefetchedForASortChange() async throws {
        let (search, transport) = makeSearch { _ in
            .init(status: 200, body: self.pageJSON(0..<2, number: 0, totalPages: 1))
        }
        await search.reload()
        #expect(search.facets.orders.map(\.value) == ["Passeriformes", "Anseriformes"])
        #expect(search.facets.orders.first?.name == "Ötücü Kuşlar" && search.facets.orders.first?.count == 228)
        #expect(search.facets.families.first?.order == "Passeriformes")
        #expect(facetRequests(transport).count == 1)

        search.sort = .scientificAscending
        await search.settled()
        #expect(facetRequests(transport).count == 1, "sorting does not change the menus")

        search.filter.order = "Passeriformes"
        await search.settled()
        #expect(facetRequests(transport).count == 2)
        #expect(query(facetRequests(transport).last)["order"] == "Passeriformes")
        #expect(!search.canFilterBySeen)
    }

    @Test func clearingTheFilterBringsBackTheFullList() async {
        let (search, transport) = makeSearch { _ in
            .init(status: 200, body: self.pageJSON(0..<2, number: 0, totalPages: 1))
        }
        search.filter = SpeciesFilter(order: "Anseriformes", family: nil, seen: .all)
        await search.settled()
        #expect(search.filter.isActive)
        search.clearFilter()
        await search.settled()
        #expect(!search.filter.isActive)
        #expect(query(lists(transport).last)["order"] == nil)
    }

    @Test func decodesRecordings() throws {
        let json = #"[{"id":"1182218","recordingUrl":"https://xeno-canto.org/1182218/download","type":"call","quality":"A","recordist":"David Darrell-Lambert","licenseUrl":"https://creativecommons.org/licenses/by-nc-sa/4.0/"}]"#
        let recordings = try JSONCoding.makeDecoder().decode([SpeciesRecording].self, from: Data(json.utf8))
        #expect(recordings.first?.recordist == "David Darrell-Lambert")
        #expect(SpeciesAPI.sounds(id: UUID()).requiresAuth == false)
    }
}

@MainActor
struct SpeciesSearchTextTests {
    private func search(for text: String) -> String? {
        SpeciesAPI.list(search: text, page: 0, language: "tr").query.first { $0.name == "search" }?.value
    }

    @Test func sendsTurkishAndScientificNamesUnchanged() {
        #expect(search(for: "serçe") == "serçe")
        #expect(search(for: "SERCE") == "SERCE")
        #expect(search(for: "Passer domesticus") == "Passer domesticus")
    }

    @Test func trimsSpacesAndSkipsAnEmptySearch() {
        #expect(search(for: "  serçe  ") == "serçe")
        #expect(search(for: "   ") == nil)
    }
}
