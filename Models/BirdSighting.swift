import Foundation
import SwiftData

/// Mirrors wingmark-backend's BirdLog entity / BirdLogResponseDto.
/// `date` ~ observedAt, `placeName` ~ locationName, `photoPath` ~ photoUrl,
/// `notes` ~ note (local names kept from before this pass; fine to leave
/// as-is since the real networking layer will map field-by-field anyway).
@Model
final class BirdSighting {
    var date: Date
    var latitude: Double?
    var longitude: Double?
    var placeName: String?
    var photoPath: String?
    var lifeStage: LifeStage
    var gender: Gender
    var notes: String?

    var isPet: Bool
    /// A pet's name, or a nickname for a wild sighting.
    var customName: String?
    var visibility: SightingVisibility

    // nil species means "I don't know" — never required.
    var species: Species?
    /// Only meaningful when `species` is set.
    var speciesStatus: SpeciesStatus?

    init(
        date: Date = .now,
        latitude: Double? = nil,
        longitude: Double? = nil,
        placeName: String? = nil,
        photoPath: String? = nil,
        lifeStage: LifeStage = .adult,
        gender: Gender = .unknown,
        notes: String? = nil,
        isPet: Bool = false,
        customName: String? = nil,
        visibility: SightingVisibility = .private,
        species: Species? = nil,
        speciesStatus: SpeciesStatus? = nil
    ) {
        self.date = date
        self.latitude = latitude
        self.longitude = longitude
        self.placeName = placeName
        self.photoPath = photoPath
        self.lifeStage = lifeStage
        self.gender = gender
        self.notes = notes
        self.isPet = isPet
        self.customName = customName
        self.visibility = visibility
        self.species = species
        self.speciesStatus = speciesStatus
    }
}
