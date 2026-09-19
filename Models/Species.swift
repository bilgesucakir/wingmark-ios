import Foundation
import SwiftData

/// Mirrors wingmark-backend's Species entity / SpeciesResponseDto.
@Model
final class Species {
    var commonName: String
    var scientificName: String

    // All optional: species info is a nice-to-have, never required to log a sighting.
    var family: String?
    var order: String?
    var speciesDescription: String?
    var lifespan: String?
    var diet: String?
    var habitat: String?
    var sizeDescription: String?
    var conservationStatus: String?
    var nativeRange: String?

    init(
        commonName: String,
        scientificName: String,
        family: String? = nil,
        order: String? = nil,
        speciesDescription: String? = nil,
        lifespan: String? = nil,
        diet: String? = nil,
        habitat: String? = nil,
        sizeDescription: String? = nil,
        conservationStatus: String? = nil,
        nativeRange: String? = nil
    ) {
        self.commonName = commonName
        self.scientificName = scientificName
        self.family = family
        self.order = order
        self.speciesDescription = speciesDescription
        self.lifespan = lifespan
        self.diet = diet
        self.habitat = habitat
        self.sizeDescription = sizeDescription
        self.conservationStatus = conservationStatus
        self.nativeRange = nativeRange
    }
}
