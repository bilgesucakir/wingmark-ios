import Foundation
import Testing
@testable import wingmark

@MainActor
struct WelcomeTourTests {
    private func tour() -> WelcomeTour {
        let defaults = UserDefaults(suiteName: "WelcomeTourTests-\(UUID().uuidString)")!
        return WelcomeTour(defaults: defaults)
    }

    @Test func showsOnTheFirstLaunch() {
        #expect(tour().isFirstLaunch)
    }

    @Test func staysHiddenOnceTheWelcomeScreenHasBeenSeen() {
        let tour = tour()
        tour.markSeen()
        #expect(!tour.isFirstLaunch)
    }

    @Test func eachDeviceKeepsItsOwnFlag() {
        let seen = tour()
        seen.markSeen()
        #expect(tour().isFirstLaunch)
    }
}
