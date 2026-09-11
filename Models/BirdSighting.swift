import Foundation
import SwiftData

@Model
final class BirdSighting {
    var date: Date
    var latitude: Double?
    var longitude: Double?
    var placeName: String?
    var photoPath: String?
    var lifeStage: LifeStage
    var notes: String?

    // nil species means "I don't know" — never required.
    var species: Species?

    init(
        date: Date = .now,
        latitude: Double? = nil,
        longitude: Double? = nil,
        placeName: String? = nil,
        photoPath: String? = nil,
        lifeStage: LifeStage = .adult,
        notes: String? = nil,
        species: Species? = nil
    ) {
        self.date = date
        self.latitude = latitude
        self.longitude = longitude
        self.placeName = placeName
        self.photoPath = photoPath
        self.lifeStage = lifeStage
        self.notes = notes
        self.species = species
    }
}
