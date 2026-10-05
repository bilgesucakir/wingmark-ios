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

    private func makeSearch(
        pause: Pause = .immediate,
        handler: @escaping (URLRequest) async throws -> MockTransport.Reply
    ) -> (SpeciesSearch, MockTransport) {
        let transport = MockTransport(handler: handler)
        let client = APIClient(baseURL: URL(string: "https://api.test")!, tokenStore: InMemoryTokenStore(),
                               transport: transport, languageCode: { "tr" })
        return (SpeciesSearch(client: client, pause: pause), transport)
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
        #expect(transport.requests.count == 1)

        await search.loadMoreIfNeeded(after: search.results[29])
        #expect(search.results.count == 45)
        #expect(!search.hasMore)
        #expect(query(transport.requests.first)["sort"] == "commonName.tr,asc")
        #expect(transport.requests.first?.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test func sortChangeReloadsWithNewParameterWithoutWaiting() async throws {
        let gate = GatedPause()
        let (search, transport) = makeSearch(pause: gate.pause) { _ in
            .init(status: 200, body: self.pageJSON(0..<3, number: 0, totalPages: 1))
        }
        await search.reload()
        search.sort = .scientificDescending
        await search.settled()
        #expect(query(transport.requests.last)["sort"] == "scientificName,desc")
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
        #expect(transport.requests.isEmpty)

        gate.release()
        await search.settled()
        #expect(transport.requests.count == 1)
        #expect(query(transport.requests.first)["search"] == "rob")
    }

    @Test func decodesRecordings() throws {
        let json = #"[{"id":"1182218","recordingUrl":"https://xeno-canto.org/1182218/download","type":"call","quality":"A","recordist":"David Darrell-Lambert","licenseUrl":"https://creativecommons.org/licenses/by-nc-sa/4.0/"}]"#
        let recordings = try JSONCoding.makeDecoder().decode([SpeciesRecording].self, from: Data(json.utf8))
        #expect(recordings.first?.recordist == "David Darrell-Lambert")
        #expect(SpeciesAPI.sounds(id: UUID()).requiresAuth == false)
    }
}
