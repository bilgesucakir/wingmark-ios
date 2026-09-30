import CoreLocation
import MapKit

enum LocationError: Error {
    case denied
    case unavailable
}

enum LocationService {
    /// Asks for When In Use permission if needed and returns one reasonably accurate fix.
    static func currentLocation(timeout: Duration = .seconds(60)) async throws(LocationError) -> CLLocation {
        let session = CLServiceSession(authorization: .whenInUse)
        defer { session.invalidate() }

        let result = await withTaskGroup(of: Result<CLLocation, LocationError>?.self) { group in
            group.addTask {
                do {
                    var best: CLLocation?
                    for try await update in CLLocationUpdate.liveUpdates() {
                        if update.authorizationDenied || update.authorizationDeniedGlobally {
                            return .failure(.denied)
                        }
                        guard let location = update.location else { continue }
                        if best == nil || location.horizontalAccuracy < best!.horizontalAccuracy { best = location }
                        if location.horizontalAccuracy <= 50 { return .success(location) }
                        if let best, best.horizontalAccuracy <= 200, update.stationary { return .success(best) }
                    }
                    return best.map { .success($0) } ?? .failure(.unavailable)
                } catch {
                    return .failure(.unavailable)
                }
            }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
        switch result {
        case .success(let location): return location
        case .failure(let error): throw error
        case nil: throw .unavailable
        }
    }

    static func placeName(for coordinate: CLLocationCoordinate2D) async -> String? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard let request = MKReverseGeocodingRequest(location: location),
              let item = try? await request.mapItems.first
        else { return nil }
        return item.address?.shortAddress ?? item.name
    }
}
