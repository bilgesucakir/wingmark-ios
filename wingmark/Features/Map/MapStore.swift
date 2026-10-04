import MapKit
import Observation

struct GeoBox: Equatable, Sendable {
    var minLat: Double
    var maxLat: Double
    var minLng: Double
    var maxLng: Double

    /// `minLng > maxLng` means the box crosses the antimeridian, which the backend accepts as-is.
    init(region: MKCoordinateRegion) {
        let halfLat = region.span.latitudeDelta / 2
        minLat = max(region.center.latitude - halfLat, -90)
        maxLat = min(region.center.latitude + halfLat, 90)
        if region.span.longitudeDelta >= 360 {
            minLng = -180
            maxLng = 180
        } else {
            let halfLng = region.span.longitudeDelta / 2
            minLng = Self.normalize(region.center.longitude - halfLng)
            maxLng = Self.normalize(region.center.longitude + halfLng)
        }
    }

    init(minLat: Double, maxLat: Double, minLng: Double, maxLng: Double) {
        self.minLat = minLat
        self.maxLat = maxLat
        self.minLng = minLng
        self.maxLng = maxLng
    }

    func contains(latitude: Double, longitude: Double) -> Bool {
        guard (minLat...maxLat).contains(latitude) else { return false }
        return minLng <= maxLng
            ? (minLng...maxLng).contains(longitude)
            : longitude >= minLng || longitude <= maxLng
    }

    static func normalize(_ longitude: Double) -> Double {
        if (-180...180).contains(longitude) { return longitude }
        let wrapped = (longitude + 180).truncatingRemainder(dividingBy: 360)
        return (wrapped < 0 ? wrapped + 360 : wrapped) - 180
    }
}

enum MapAPI {
    static func logs(in box: GeoBox, filter: DiaryFilter, limit: Int = 500) -> Endpoint<[BirdLog]> {
        var query = [
            URLQueryItem(name: "minLat", value: String(box.minLat)),
            URLQueryItem(name: "maxLat", value: String(box.maxLat)),
            URLQueryItem(name: "minLng", value: String(box.minLng)),
            URLQueryItem(name: "maxLng", value: String(box.maxLng)),
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        query.append(contentsOf: filter.queryItems)
        return Endpoint(.get, "bird-logs/location", query: query)
    }
}

struct MapCluster: Identifiable, Equatable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let logs: [BirdLog]

    static func == (lhs: MapCluster, rhs: MapCluster) -> Bool {
        lhs.id == rhs.id && lhs.logs.map(\.id) == rhs.logs.map(\.id)
    }

    /// Sightings within about a metre of each other count as the same spot (5 decimal places of a degree).
    static func spotKey(_ log: BirdLog) -> String {
        "\(Int((log.latitude * 100_000).rounded())):\(Int((log.longitude * 100_000).rounded()))"
    }

    /// False when every sighting in the cluster is at one spot, so zooming in could never separate them.
    var hasSeparateSpots: Bool { Set(logs.map(Self.spotKey)).count > 1 }

    /// Buckets logs into a grid sized to the visible span; single-log buckets stay plain pins.
    /// Fully zoomed in, only sightings at the same spot are grouped, so none is hidden under another pin.
    static func make(from logs: [BirdLog], region: MKCoordinateRegion, columns: Double = 5, rows: Double = 7) -> [MapCluster] {
        let box = GeoBox(region: region)
        let visible = logs.filter { $0.hasLocation && box.contains(latitude: $0.latitude, longitude: $0.longitude) }
        guard region.span.latitudeDelta > 0.002 else {
            return Dictionary(grouping: visible, by: spotKey).map { key, members in
                members.count == 1
                    ? MapCluster(id: members[0].id.uuidString, coordinate: members[0].coordinate, logs: members)
                    : MapCluster(id: "spot-\(key)", coordinate: members[0].coordinate, logs: members)
            }
        }
        let cellLat = region.span.latitudeDelta / rows
        let cellLng = min(region.span.longitudeDelta, 360) / columns
        let groups = Dictionary(grouping: visible) { log in
            "\(Int((log.latitude / cellLat).rounded(.down))):\(Int((log.longitude / cellLng).rounded(.down)))"
        }
        return groups.map { key, members in
            if members.count == 1 {
                return MapCluster(id: members[0].id.uuidString, coordinate: members[0].coordinate, logs: members)
            }
            let latitude = members.map(\.latitude).reduce(0, +) / Double(members.count)
            let longitude = members.map(\.longitude).reduce(0, +) / Double(members.count)
            return MapCluster(id: "cluster-\(key)", coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                              logs: members)
        }
    }
}

extension BirdLog {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

@Observable
final class MapStore {
    private(set) var logs: [UUID: BirdLog] = [:]
    private(set) var isTruncated = false
    private(set) var isLoading = false
    private(set) var loadError: APIError?
    private(set) var region: MKCoordinateRegion?

    var filter = DiaryFilter() {
        didSet {
            guard filter != oldValue else { return }
            logs = [:]
            schedule(debounce: false)
        }
    }

    private let session: AuthSession
    private let diary: DiaryStore
    private var loadTask: Task<Void, Never>?

    init(session: AuthSession, diary: DiaryStore) {
        self.session = session
        self.diary = diary
    }

    func regionDidChange(_ region: MKCoordinateRegion) {
        self.region = region
        schedule(debounce: true)
    }

    /// Drops the cache and reloads the visible region, e.g. after a sighting changed elsewhere.
    func reset() {
        logs = [:]
        schedule(debounce: false)
    }

    func reload() {
        schedule(debounce: false)
    }

    private func schedule(debounce: Bool) {
        loadTask?.cancel()
        loadTask = Task {
            if debounce { try? await Task.sleep(for: .milliseconds(300)) }
            guard !Task.isCancelled, let region else { return }
            await load(region: region)
        }
    }

    private func load(region: MKCoordinateRegion) async {
        let box = GeoBox(region: region)
        let filter = filter
        isLoading = true
        defer { isLoading = false }
        do throws(APIError) {
            let (result, response) = try await session.client.sendReturningResponse(MapAPI.logs(in: box, filter: filter))
            guard !Task.isCancelled, filter == self.filter else { return }
            let truncated = response.value(forHTTPHeaderField: "X-Result-Truncated")?.lowercased() == "true"
            if !truncated {
                // Anything cached inside this box that didn't come back was deleted or filtered out.
                logs = logs.filter { !box.contains(latitude: $0.value.latitude, longitude: $0.value.longitude) }
            }
            for log in result { logs[log.id] = log }
            isTruncated = truncated
            loadError = nil
            diary.remember(result)
        } catch {
            guard !error.isCancellation else { return }
            if error.code == .invalidBounds || error.code == .invalidParameter {
                isTruncated = false
            } else {
                loadError = error
            }
        }
    }
}
