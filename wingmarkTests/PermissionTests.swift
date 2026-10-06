import AVFoundation
import CoreLocation
import Foundation
import Testing
@testable import wingmark

@MainActor
@Suite(.serialized)
struct PermissionTests {
    private final class Calls { var requests = 0 }

    private func client(camera: PermissionState, grants: Bool = true, calls: Calls = Calls()) -> PermissionClient {
        PermissionClient(
            state: { $0 == .camera ? camera : .notAsked },
            requestCamera: {
                calls.requests += 1
                return grants
            }
        )
    }

    private func withLanguage(_ language: AppLanguage, _ body: () -> Void) {
        let previous = UserDefaults.standard.string(forKey: AppLanguage.storageKey)
        UserDefaults.standard.set(language.rawValue, forKey: AppLanguage.storageKey)
        body()
        UserDefaults.standard.set(previous, forKey: AppLanguage.storageKey)
    }

    @Test func mapsTheSystemCameraStatuses() {
        #expect(PermissionState(camera: .authorized) == .allowed)
        #expect(PermissionState(camera: .denied) == .notAllowed)
        #expect(PermissionState(camera: .restricted) == .restricted)
        #expect(PermissionState(camera: .notDetermined) == .notAsked)
    }

    @Test func mapsTheSystemLocationStatuses() {
        #expect(PermissionState(location: .authorizedWhenInUse) == .allowed)
        #expect(PermissionState(location: .authorizedAlways) == .allowed)
        #expect(PermissionState(location: .denied) == .notAllowed)
        #expect(PermissionState(location: .restricted) == .restricted)
        #expect(PermissionState(location: .notDetermined) == .notAsked)
    }

    @Test func onlyAPermissionThatIsOffOffersSettings() {
        #expect(PermissionState.notAllowed.offersSettings)
        for state in [PermissionState.allowed, .notAsked, .restricted] {
            #expect(!state.offersSettings)
        }
    }

    @Test func anAllowedCameraOpensWithoutAsking() async {
        let calls = Calls()
        #expect(await CameraAccess.resolve(using: client(camera: .allowed, calls: calls)) == .open)
        #expect(calls.requests == 0)
    }

    @Test func asksOnceTheFirstTimeAndOpensWhenGranted() async {
        let calls = Calls()
        #expect(await CameraAccess.resolve(using: client(camera: .notAsked, grants: true, calls: calls)) == .open)
        #expect(calls.requests == 1)
    }

    @Test func aRefusedFirstRequestBlocksAsNotAllowed() async {
        let calls = Calls()
        let result = await CameraAccess.resolve(using: client(camera: .notAsked, grants: false, calls: calls))
        #expect(result == .blocked(PermissionIssue(kind: .camera, state: .notAllowed)))
        #expect(calls.requests == 1)
    }

    @Test func aCameraThatIsOffIsNeverAskedAgain() async {
        let calls = Calls()
        let result = await CameraAccess.resolve(using: client(camera: .notAllowed, grants: true, calls: calls))
        #expect(result == .blocked(PermissionIssue(kind: .camera, state: .notAllowed)))
        #expect(calls.requests == 0)
    }

    @Test func aRestrictedCameraIsReportedWithoutAsking() async {
        let calls = Calls()
        let result = await CameraAccess.resolve(using: client(camera: .restricted, calls: calls))
        #expect(result == .blocked(PermissionIssue(kind: .camera, state: .restricted)))
        #expect(calls.requests == 0)
    }

    @Test func alertTextDiffersBetweenOffAndRestricted() {
        let off = PermissionIssue(kind: .camera, state: .notAllowed)
        let restricted = PermissionIssue(kind: .camera, state: .restricted)
        #expect(off.title != restricted.title && off.message != restricted.message)
        #expect(off.message.contains("library"))
        let locationOff = PermissionIssue(kind: .location, state: .notAllowed)
        #expect(locationOff.title == "Location access is off")
    }

    @Test func everyStringIsTranslatedToTurkish() {
        func texts() -> [String] {
            PermissionKind.allCases.flatMap { [$0.title, $0.reason] }
                + [PermissionState.allowed, .notAllowed, .notAsked, .restricted].map(\.title)
                + PermissionKind.allCases.flatMap { kind in
                    [PermissionState.notAllowed, .restricted].flatMap { [PermissionIssue(kind: kind, state: $0).title, PermissionIssue(kind: kind, state: $0).message] }
                }
        }
        var english: [String] = []
        var turkish: [String] = []
        withLanguage(.english) { english = texts() }
        withLanguage(.turkish) { turkish = texts() }
        #expect(english.count == turkish.count)
        for (en, tr) in zip(english, turkish) {
            #expect(en != tr, "\(en) has no Turkish translation")
        }
    }

    @Test func theMicrophoneStaysOut() {
        #expect(Bundle.main.object(forInfoDictionaryKey: "NSMicrophoneUsageDescription") == nil)
        #expect(Bundle.main.object(forInfoDictionaryKey: "NSCameraUsageDescription") != nil)
    }
}
