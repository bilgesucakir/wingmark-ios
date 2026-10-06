import Photos
import SwiftUI

enum PhotoSaveResult: Equatable {
    case saved
    case blocked(PermissionIssue)
    case failed
}

/// Saves a sighting's photo to the library. Tests pass their own pieces, so no real prompt or write happens.
struct PhotoSaver {
    var permissions: PermissionClient = .live
    var load: (URL) async -> Data? = { await ImageLoader.shared.data(for: $0) }
    var write: (Data) async throws -> Void = { data in
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetCreationRequest.forAsset().addResource(with: .photo, data: data, options: nil)
        }
    }

    func save(path: String?) async -> PhotoSaveResult {
        guard let url = path.flatMap({ AppConfig.assetURL(for: $0) }) else { return .failed }
        if case .blocked(let issue) = await PhotoSaveAccess.resolve(using: permissions) { return .blocked(issue) }
        guard let data = await load(url) else { return .failed }
        do {
            try await write(data)
            return .saved
        } catch {
            return .failed
        }
    }
}
