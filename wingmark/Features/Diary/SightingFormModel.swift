import CoreLocation
import Foundation
import Observation
import UIKit

@Observable
final class SightingFormModel {
    enum Photo {
        case none
        case existing(String)
        case new(ProcessedPhoto)
    }

    enum LocationSource { case none, device, photo, manual }

    enum LocationStatus: Equatable {
        case idle, locating
        case failed(String)
    }

    struct SpeciesChoice: Equatable {
        let id: UUID
        let name: String
    }

    let editing: BirdLog?

    var photo: Photo
    var isProcessingPhoto = false
    var photoError: String?

    var observedAt: Date {
        didSet { if observedAt != oldValue, !isApplyingPhotoDate { dateFromPhoto = false } }
    }
    /// New sightings default to "seen now"; the date picker only appears when this is off.
    var seenNow: Bool {
        didSet {
            if seenNow {
                dateFromPhoto = false
            } else if !isApplyingPhotoDate, editing == nil {
                observedAt = .now
            }
        }
    }
    private(set) var dateFromPhoto = false
    private var isApplyingPhotoDate = false
    var coordinate: CLLocationCoordinate2D?
    var locationSource: LocationSource
    var locationStatus: LocationStatus = .idle
    var locationName: String

    var species: SpeciesChoice?
    var dontKnowSpecies: Bool
    var speciesStatus: SpeciesStatus
    var lifeStage: LifeStage
    var gender: Gender
    var pet: Bool
    var customName: String
    var note: String

    private let originalObservedAt: Date?
    private var suggestedPlaceName: String?

    init(editing log: BirdLog?) {
        editing = log
        photo = log?.photoUrl.map(Photo.existing) ?? .none
        observedAt = log?.observedAt ?? .now
        seenNow = log == nil
        originalObservedAt = log?.observedAt
        coordinate = log.flatMap { $0.hasLocation ? CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) : nil }
        locationSource = log?.hasLocation == true ? .manual : .none
        locationName = log?.locationName ?? ""
        species = log.flatMap { log in
            log.speciesId.map { SpeciesChoice(id: $0, name: log.speciesCommonName ?? "") }
        }
        dontKnowSpecies = log != nil && log?.speciesId == nil
        speciesStatus = log?.speciesStatus ?? .confident
        lifeStage = log?.lifeStage ?? .unknown
        gender = log?.gender ?? .unknown
        pet = log?.pet ?? false
        customName = log?.customName ?? ""
        note = log?.note ?? ""
    }

    var canSave: Bool { coordinate != nil && !isProcessingPhoto }

    var newPhoto: ProcessedPhoto? {
        if case .new(let photo) = photo { return photo }
        return nil
    }

    func makeInput() -> BirdLogInput? {
        guard let coordinate else { return nil }
        let speciesId = dontKnowSpecies ? nil : species?.id
        var existingPhotoURL: String?
        if case .existing(let url) = photo { existingPhotoURL = url }
        return BirdLogInput(
            speciesId: speciesId,
            speciesStatus: speciesId == nil ? nil : speciesStatus,
            pet: pet,
            customName: Self.nonEmpty(customName),
            lifeStage: lifeStage,
            gender: gender,
            photoUrl: existingPhotoURL,
            note: Self.nonEmpty(note),
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            locationName: Self.nonEmpty(locationName),
            observedAt: observedAtToSend
        )
    }

    /// On edit, omitting `observedAt` keeps the stored value.
    private var observedAtToSend: Date? {
        if seenNow { return .now }
        guard let originalObservedAt else { return min(observedAt, .now) }
        return abs(observedAt.timeIntervalSince(originalObservedAt)) < 1 ? nil : min(observedAt, .now)
    }

    // MARK: - Photo

    func loadPhoto(data: Data) async {
        await process { PhotoProcessing.process(data) }
    }

    func loadPhoto(image: UIImage) async {
        await process { PhotoProcessing.process(image) }
    }

    func removePhoto() {
        photo = .none
    }

    private func process(_ work: @escaping @Sendable () -> ProcessedPhoto?) async {
        isProcessingPhoto = true
        photoError = nil
        defer { isProcessingPhoto = false }
        guard let processed = await Task.detached(priority: .userInitiated, operation: work).value else {
            photoError = String(localized: "Couldn't read that photo.", bundle: .app)
            return
        }
        photo = .new(processed)
        if let capturedAt = processed.metadata.capturedAt {
            isApplyingPhotoDate = true
            seenNow = false
            observedAt = min(capturedAt, .now)
            dateFromPhoto = true
            isApplyingPhotoDate = false
        }
        if let coordinate = processed.metadata.coordinate, locationSource != .manual {
            await setCoordinate(coordinate, source: .photo)
        }
    }

    // MARK: - Location

    func locateIfNeeded() async {
        guard coordinate == nil, locationStatus == .idle else { return }
        await useCurrentLocation()
    }

    func useCurrentLocation() async {
        locationStatus = .locating
        do throws(LocationError) {
            let location = try await LocationService.currentLocation()
            locationStatus = .idle
            // A photo's location arrived while we were waiting; keep it.
            if locationSource == .photo { return }
            await setCoordinate(location.coordinate, source: .device)
        } catch {
            locationStatus = .failed(error == .denied
                ? String(localized: "Location access is off. Allow it in Settings or pick the spot on the map.", bundle: .app)
                : String(localized: "Couldn't find your location. Pick the spot on the map.", bundle: .app))
        }
    }

    func setCoordinate(_ coordinate: CLLocationCoordinate2D, source: LocationSource) async {
        self.coordinate = coordinate
        locationSource = source
        guard locationName.isEmpty || locationName == suggestedPlaceName else { return }
        if let name = await LocationService.placeName(for: coordinate),
           self.coordinate?.latitude == coordinate.latitude, self.coordinate?.longitude == coordinate.longitude,
           locationName.isEmpty || locationName == suggestedPlaceName {
            suggestedPlaceName = name
            locationName = name
        }
    }

    private static func nonEmpty(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
