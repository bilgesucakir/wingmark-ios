import Foundation
import SwiftData

@Model
final class Species {
    var commonName: String
    var scientificName: String

    // All optional: species info is a nice-to-have, never required to log a sighting.
    var speciesDescription: String?
    var habitat: String?
    var diet: String?
    var sizeInfo: String?

    init(
        commonName: String,
        scientificName: String,
        speciesDescription: String? = nil,
        habitat: String? = nil,
        diet: String? = nil,
        sizeInfo: String? = nil
    ) {
        self.commonName = commonName
        self.scientificName = scientificName
        self.speciesDescription = speciesDescription
        self.habitat = habitat
        self.diet = diet
        self.sizeInfo = sizeInfo
    }
}
