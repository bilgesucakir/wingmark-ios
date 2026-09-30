import CoreLocation
import Observation

/// Rough current location for "distance from you". Never asks for permission itself.
@Observable
final class UserLocation: NSObject, CLLocationManagerDelegate {
    static let shared = UserLocation()

    private(set) var location: CLLocation?
    private let manager = CLLocationManager()

    override private init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 100
    }

    func start() {
        guard isAuthorized else { return }
        location = manager.location ?? location
        manager.startUpdatingLocation()
    }

    func stop() {
        manager.stopUpdatingLocation()
    }

    func distance(to log: BirdLog) -> CLLocationDistance? {
        guard log.hasLocation, let location else { return nil }
        return location.distance(from: CLLocation(latitude: log.latitude, longitude: log.longitude))
    }

    private var isAuthorized: Bool {
        [.authorizedWhenInUse, .authorizedAlways].contains(manager.authorizationStatus)
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        Task { @MainActor in self.location = latest }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in self.start() }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {}
}
