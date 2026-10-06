import Foundation
import Photos
import Testing
@testable import wingmark

@MainActor
struct PhotoSaveTests {
    private final class Calls {
        var requests = 0
        var loads = 0
        var writes: [Data] = []
    }

    private func saver(photos: PermissionState, grants: Bool = true, data: Data? = Data([1, 2, 3]),
                       writeFails: Bool = false, calls: Calls) -> PhotoSaver {
        PhotoSaver(
            permissions: PermissionClient(
                state: { $0 == .photos ? photos : .notAsked },
                requestCamera: { false },
                requestPhotosAddOnly: {
                    calls.requests += 1
                    return grants
                }
            ),
            load: { _ in
                calls.loads += 1
                return data
            },
            write: { data in
                if writeFails { throw URLError(.cannotWriteToFile) }
                calls.writes.append(data)
            }
        )
    }

    @Test func mapsTheSystemPhotoStatuses() {
        #expect(PermissionState(photosAddOnly: .authorized) == .allowed)
        #expect(PermissionState(photosAddOnly: .limited) == .allowed)
        #expect(PermissionState(photosAddOnly: .denied) == .notAllowed)
        #expect(PermissionState(photosAddOnly: .restricted) == .restricted)
        #expect(PermissionState(photosAddOnly: .notDetermined) == .notAsked)
    }

    @Test func savesTheFileAsTheServerSentItWithoutAsking() async {
        let calls = Calls()
        let result = await saver(photos: .allowed, calls: calls).save(path: "/uploads/a.jpg")
        #expect(result == .saved)
        #expect(calls.requests == 0)
        #expect(calls.writes == [Data([1, 2, 3])])
    }

    @Test func asksOnceInContextAndSavesWhenGranted() async {
        let calls = Calls()
        #expect(await saver(photos: .notAsked, calls: calls).save(path: "/uploads/a.jpg") == .saved)
        #expect(calls.requests == 1)
    }

    @Test func aRefusedPromptSavesNothing() async {
        let calls = Calls()
        let result = await saver(photos: .notAsked, grants: false, calls: calls).save(path: "/uploads/a.jpg")
        #expect(result == .blocked(PermissionIssue(kind: .photos, state: .notAllowed)))
        #expect(calls.loads == 0 && calls.writes.isEmpty)
    }

    @Test func aTurnedOffPermissionIsNotAskedAgain() async {
        let calls = Calls()
        let result = await saver(photos: .notAllowed, calls: calls).save(path: "/uploads/a.jpg")
        #expect(result == .blocked(PermissionIssue(kind: .photos, state: .notAllowed)))
        #expect(calls.requests == 0)
    }

    @Test func aRestrictedLibraryIsReported() async {
        let calls = Calls()
        let result = await saver(photos: .restricted, calls: calls).save(path: "/uploads/a.jpg")
        #expect(result == .blocked(PermissionIssue(kind: .photos, state: .restricted)))
    }

    @Test func failsWhenTheDownloadOrTheWriteFails() async {
        let calls = Calls()
        #expect(await saver(photos: .allowed, data: nil, calls: calls).save(path: "/uploads/a.jpg") == .failed)
        #expect(await saver(photos: .allowed, writeFails: true, calls: calls).save(path: "/uploads/a.jpg") == .failed)
        #expect(await saver(photos: .allowed, calls: calls).save(path: nil) == .failed)
    }

    @Test func onlyAddAccessIsDeclared() {
        #expect(Bundle.main.object(forInfoDictionaryKey: "NSPhotoLibraryAddUsageDescription") != nil)
        #expect(Bundle.main.object(forInfoDictionaryKey: "NSPhotoLibraryUsageDescription") == nil)
    }
}
