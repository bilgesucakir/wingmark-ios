import AVFoundation
import CoreLocation
import Photos
import SwiftUI

/// What the app asks the system for. Photos is add-only: the app can save a picture but never reads the library.
enum PermissionKind: CaseIterable, Identifiable {
    case camera, location, photos

    var id: Self { self }

    var title: String {
        switch self {
        case .camera: String(localized: "Camera", bundle: .app)
        case .location: String(localized: "Location", bundle: .app)
        case .photos: String(localized: "Photos", bundle: .app)
        }
    }

    var symbol: String {
        switch self {
        case .camera: "camera"
        case .location: "location"
        case .photos: "photo.on.rectangle"
        }
    }

    /// Why the app needs it, shown next to Open Settings when it is off.
    var reason: String {
        switch self {
        case .camera: String(localized: "Used to take photos of the birds you spot.", bundle: .app)
        case .location: String(localized: "Used to save where you spotted each bird and to show you on the map.", bundle: .app)
        case .photos: String(localized: "Used to save a sighting's photo to your library.", bundle: .app)
        }
    }
}

enum PermissionState: Equatable {
    case allowed, notAllowed, notAsked, restricted

    var title: String {
        switch self {
        case .allowed: String(localized: "Allowed", bundle: .app)
        case .notAllowed: String(localized: "Not allowed", bundle: .app)
        case .notAsked: String(localized: "Not asked yet", bundle: .app)
        case .restricted: String(localized: "Restricted", bundle: .app)
        }
    }

    /// Only a permission the person turned off can be fixed in Settings; "not asked yet" is asked in context,
    /// and "restricted" (for example Screen Time) isn't theirs to change here.
    var offersSettings: Bool { self == .notAllowed }

    init(camera status: AVAuthorizationStatus) {
        switch status {
        case .authorized: self = .allowed
        case .denied: self = .notAllowed
        case .restricted: self = .restricted
        case .notDetermined: self = .notAsked
        @unknown default: self = .notAllowed
        }
    }

    init(photosAddOnly status: PHAuthorizationStatus) {
        switch status {
        case .authorized, .limited: self = .allowed
        case .denied: self = .notAllowed
        case .restricted: self = .restricted
        case .notDetermined: self = .notAsked
        @unknown default: self = .notAllowed
        }
    }

    init(location status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways: self = .allowed
        case .denied: self = .notAllowed
        case .restricted: self = .restricted
        case .notDetermined: self = .notAsked
        @unknown default: self = .notAllowed
        }
    }
}

/// Reads permission state and asks for the camera. Tests pass their own, so no real prompt is ever shown.
struct PermissionClient {
    var state: (PermissionKind) -> PermissionState
    var requestCamera: () async -> Bool
    var requestPhotosAddOnly: () async -> Bool = { false }

    static let live = PermissionClient(
        state: { kind in
            switch kind {
            case .camera: PermissionState(camera: AVCaptureDevice.authorizationStatus(for: .video))
            case .location: PermissionState(location: CLLocationManager().authorizationStatus)
            case .photos: PermissionState(photosAddOnly: PHPhotoLibrary.authorizationStatus(for: .addOnly))
            }
        },
        requestCamera: { await AVCaptureDevice.requestAccess(for: .video) },
        requestPhotosAddOnly: { PermissionState(photosAddOnly: await PHPhotoLibrary.requestAuthorization(for: .addOnly)) == .allowed }
    )
}

/// A permission that blocks what the person just tried to do.
struct PermissionIssue: Identifiable, Equatable {
    let kind: PermissionKind
    let state: PermissionState

    var id: String { "\(kind)-\(state)" }

    var title: String {
        switch (kind, state) {
        case (.camera, .restricted): String(localized: "Camera is restricted", bundle: .app)
        case (.camera, _): String(localized: "Camera access is off", bundle: .app)
        case (.location, .restricted): String(localized: "Location is restricted", bundle: .app)
        case (.location, _): String(localized: "Location access is off", bundle: .app)
        case (.photos, .restricted): String(localized: "Saving photos is restricted", bundle: .app)
        case (.photos, _): String(localized: "Saving photos is off", bundle: .app)
        }
    }

    var message: String {
        switch (kind, state) {
        case (.camera, .restricted):
            String(localized: "The camera is restricted on this iPhone, so Wingmark can't use it. You can still choose a photo from your library.", bundle: .app)
        case (.camera, _):
            String(localized: "Allow Wingmark to use the camera in Settings to take bird photos. You can still choose a photo from your library.", bundle: .app)
        case (.location, .restricted):
            String(localized: "Location is restricted on this iPhone, so Wingmark can't use it.", bundle: .app)
        case (.location, _):
            String(localized: "Allow Wingmark to use your location in Settings to see where you are on the map.", bundle: .app)
        case (.photos, .restricted):
            String(localized: "Saving to Photos is restricted on this iPhone, so Wingmark can't save this picture.", bundle: .app)
        case (.photos, _):
            String(localized: "Allow Wingmark to add photos in Settings to save this picture to your library.", bundle: .app)
        }
    }
}

/// Decides what happens when the person taps Take Photo.
enum CameraAccess: Equatable {
    case open
    case blocked(PermissionIssue)

    /// Never prompts twice: it asks only when the system hasn't asked yet, and a refusal is not asked again.
    static func resolve(using client: PermissionClient = .live) async -> CameraAccess {
        switch client.state(.camera) {
        case .allowed:
            return .open
        case .notAsked:
            return await client.requestCamera() ? .open : .blocked(PermissionIssue(kind: .camera, state: .notAllowed))
        case .notAllowed:
            return .blocked(PermissionIssue(kind: .camera, state: .notAllowed))
        case .restricted:
            return .blocked(PermissionIssue(kind: .camera, state: .restricted))
        }
    }
}

/// Decides what happens when the person taps Save Photo. Only asks for add-only access, never to read the library.
enum PhotoSaveAccess: Equatable {
    case allowed
    case blocked(PermissionIssue)

    static func resolve(using client: PermissionClient = .live) async -> PhotoSaveAccess {
        switch client.state(.photos) {
        case .allowed:
            return .allowed
        case .notAsked:
            return await client.requestPhotosAddOnly() ? .allowed : .blocked(PermissionIssue(kind: .photos, state: .notAllowed))
        case .notAllowed:
            return .blocked(PermissionIssue(kind: .photos, state: .notAllowed))
        case .restricted:
            return .blocked(PermissionIssue(kind: .photos, state: .restricted))
        }
    }
}

private struct PermissionAlert: ViewModifier {
    @Binding var issue: PermissionIssue?
    @Environment(\.openURL) private var openURL

    func body(content: Content) -> some View {
        content.alert(
            Text(issue?.title ?? ""),
            isPresented: Binding(get: { issue != nil }, set: { if !$0 { issue = nil } }),
            presenting: issue
        ) { issue in
            if issue.state.offersSettings {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                Button("Cancel", role: .cancel) {}
            } else {
                Button("OK", role: .cancel) {}
            }
        } message: { issue in
            Text(issue.message)
        }
    }
}

extension View {
    /// One alert for every blocked permission: explains it, offers Open Settings when the person turned it off.
    func permissionAlert(_ issue: Binding<PermissionIssue?>) -> some View {
        modifier(PermissionAlert(issue: issue))
    }
}
