import Foundation
import MapKit
import Testing
@testable import wingmark

@MainActor
struct GeoBoxTests {
    @Test func regularRegion() {
        let box = GeoBox(region: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 41, longitude: 29),
            span: MKCoordinateSpan(latitudeDelta: 2, longitudeDelta: 4)
        ))
        #expect(box == GeoBox(minLat: 40, maxLat: 42, minLng: 27, maxLng: 31))
        #expect(box.contains(latitude: 41, longitude: 29))
        #expect(!box.contains(latitude: 41, longitude: 32))
    }

    @Test func crossingTheAntimeridianKeepsMinGreaterThanMax() {
        let box = GeoBox(region: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: -17, longitude: 179),
            span: MKCoordinateSpan(latitudeDelta: 2, longitudeDelta: 6)
        ))
        #expect(box.minLng == 176)
        #expect(box.maxLng == -178)
        #expect(box.contains(latitude: -17, longitude: 179.5))
        #expect(box.contains(latitude: -17, longitude: -179))
        #expect(!box.contains(latitude: -17, longitude: 0))
    }

    @Test func clampsLatitudeAndCoversTheWorld() {
        let box = GeoBox(region: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 80, longitude: 0),
            span: MKCoordinateSpan(latitudeDelta: 40, longitudeDelta: 400)
        ))
        #expect(box == GeoBox(minLat: 60, maxLat: 90, minLng: -180, maxLng: 180))
    }

    @Test(arguments: [(190.0, -170.0), (-190.0, 170.0), (540.0, 180.0), (45.0, 45.0)])
    func normalizesLongitude(_ input: Double, _ expected: Double) {
        #expect(GeoBox.normalize(input) == expected || abs(GeoBox.normalize(input)) == 180 && abs(expected) == 180)
    }
}

@MainActor
struct ClusterTests {
    private func log(_ id: Int, _ latitude: Double, _ longitude: Double) throws -> BirdLog {
        let uuid = String(format: "00000000-0000-0000-0000-%012d", id)
        let json = DiaryFixtures.logJSON(id: uuid, observedAt: "2026-09-29T07:30:00Z")
            .replacingOccurrences(of: #""latitude":41.01"#, with: #""latitude":\#(latitude)"#)
            .replacingOccurrences(of: #""longitude":28.97"#, with: #""longitude":\#(longitude)"#)
        return try JSONCoding.makeDecoder().decode(BirdLog.self, from: Data(json.utf8))
    }

    @Test func groupsNearbyLogsWhenZoomedOut() throws {
        let logs = [try log(1, 41.001, 29.001), try log(2, 41.002, 29.002), try log(3, 45, 35)]
        let region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 42, longitude: 31),
                                        span: MKCoordinateSpan(latitudeDelta: 14, longitudeDelta: 14))
        let clusters = MapCluster.make(from: logs, region: region)
        #expect(clusters.count == 2)
        #expect(clusters.contains { $0.logs.count == 2 })
    }

    @Test func showsEveryPinWhenZoomedFarIn() throws {
        let logs = [try log(1, 41.0001, 29.0001), try log(2, 41.0002, 29.0002)]
        let region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 41, longitude: 29),
                                        span: MKCoordinateSpan(latitudeDelta: 0.001, longitudeDelta: 0.001))
        #expect(MapCluster.make(from: logs, region: region).allSatisfy { $0.logs.count == 1 })
    }

    @Test func groupsSightingsAtTheSameSpotEvenWhenFullyZoomedIn() throws {
        let logs = [try log(1, 41.0, 29.0), try log(2, 41.0, 29.0), try log(3, 41.0, 29.0), try log(4, 41.0004, 29.0004)]
        let region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 41, longitude: 29),
                                        span: MKCoordinateSpan(latitudeDelta: 0.001, longitudeDelta: 0.001))
        let clusters = MapCluster.make(from: logs, region: region)
        #expect(clusters.count == 2)
        let sameSpot = try #require(clusters.first { $0.logs.count == 3 })
        #expect(Set(sameSpot.logs.map(\.id)) == Set(logs.prefix(3).map(\.id)))
        #expect(!sameSpot.hasSeparateSpots)
        #expect(clusters.contains { $0.logs.count == 1 })
    }

    @Test func aClusterKnowsWhetherZoomingInCouldSeparateIt() throws {
        let region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 42, longitude: 31),
                                        span: MKCoordinateSpan(latitudeDelta: 14, longitudeDelta: 14))
        let apart = MapCluster.make(from: [try log(1, 41.001, 29.001), try log(2, 41.002, 29.002)], region: region)
        #expect(apart.count == 1 && apart[0].hasSeparateSpots)
        let together = MapCluster.make(from: [try log(1, 41.001, 29.001), try log(2, 41.001, 29.001)], region: region)
        #expect(together.count == 1 && !together[0].hasSeparateSpots)
    }

    @Test func skipsLogsOutsideTheRegion() throws {
        let region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 41, longitude: 29),
                                        span: MKCoordinateSpan(latitudeDelta: 1, longitudeDelta: 1))
        #expect(MapCluster.make(from: [try log(1, 10, 10)], region: region).isEmpty)
    }
}

@MainActor
struct MapStoreTests {
    private let region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 41, longitude: 29),
                                            span: MKCoordinateSpan(latitudeDelta: 1, longitudeDelta: 1))

    private func makeStore(
        pause: Pause = .immediate,
        handler: @escaping (URLRequest) async throws -> MockTransport.Reply
    ) async -> (MapStore, DiaryStore, MockTransport) {
        let transport = MockTransport(handler: handler)
        let client = APIClient(baseURL: URL(string: "https://api.test")!,
                               tokenStore: InMemoryTokenStore(Fixtures.tokens("a")), transport: transport)
        let session = AuthSession(client: client)
        await session.restore()
        let diary = DiaryStore(session: session)
        return (MapStore(session: session, diary: diary, pause: pause), diary, transport)
    }

    @Test func loadsRegionWithFilterAndReadsTruncation() async throws {
        let id = "11111111-1111-1111-1111-111111111111"
        let (store, diary, transport) = await makeStore { request in
            guard request.url?.path == "/api/bird-logs/location" else {
                return .init(status: 200, body: request.url?.path.hasSuffix("settings") == true
                             ? #"{"unitPreference":"METRIC","locale":"en"}"# : Fixtures.userJSON)
            }
            return .init(status: 200, body: "[\(DiaryFixtures.logJSON(id: id, observedAt: "2026-09-29T07:30:00Z"))]",
                         headers: ["X-Result-Truncated": "true"])
        }
        store.filter.gender = .female
        store.regionDidChange(region)
        await store.settled()

        #expect(store.logs.count == 1)
        #expect(store.isTruncated)
        #expect(diary.log(id: UUID(uuidString: id)!) != nil)
        let query = try #require(transport.requests(to: "/api/bird-logs/location").last?.url?.query)
        #expect(query.contains("minLat=40.5") && query.contains("maxLng=29.5"))
        #expect(query.contains("limit=500") && query.contains("gender=FEMALE"))
    }

    @Test func untruncatedReloadDropsLogsMissingFromTheBox() async throws {
        let id = "11111111-1111-1111-1111-111111111111"
        var serverLogs = [DiaryFixtures.logJSON(id: id, observedAt: "2026-09-29T07:30:00Z")]
        let (store, _, _) = await makeStore { request in
            guard request.url?.path == "/api/bird-logs/location" else {
                return .init(status: 200, body: request.url?.path.hasSuffix("settings") == true
                             ? #"{"unitPreference":"METRIC","locale":"en"}"# : Fixtures.userJSON)
            }
            return .init(status: 200, body: "[\(serverLogs.joined(separator: ","))]")
        }
        store.regionDidChange(region)
        await store.settled()
        #expect(store.logs.count == 1)

        serverLogs = []
        store.reload()
        await store.settled()
        #expect(store.logs.isEmpty)
        #expect(!store.isTruncated)
    }

    @Test func panningIsDebouncedIntoOneLoad() async throws {
        let gate = GatedPause()
        let (store, _, transport) = await makeStore(pause: gate.pause) { request in
            request.url?.path == "/api/bird-logs/location"
                ? .init(status: 200, body: "[]")
                : .init(status: 200, body: request.url?.path.hasSuffix("settings") == true
                        ? #"{"unitPreference":"METRIC","locale":"en"}"# : Fixtures.userJSON)
        }
        store.regionDidChange(region)
        store.regionDidChange(region)
        store.regionDidChange(region)
        await gate.waitUntilWaiting(count: 3)

        #expect(gate.requested == Array(repeating: .milliseconds(300), count: 3))
        #expect(transport.requests(to: "/api/bird-logs/location").isEmpty)

        gate.release()
        await store.settled()
        #expect(transport.requests(to: "/api/bird-logs/location").count == 1)
    }
}
