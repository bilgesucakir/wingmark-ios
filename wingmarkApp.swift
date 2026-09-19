//
//  wingmarkApp.swift
//  wingmark
//
//  Created by Bilgesu Çakır on 12.09.2026.
//

import SwiftUI
import SwiftData

@main
struct wingmarkApp: App {
    @State private var authSession = AuthSession()
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.system.rawValue

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            BirdSighting.self,
            Species.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            seedSpeciesCatalogIfNeeded(in: container.mainContext)
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            AuthGateView()
                .environment(authSession)
                .environment(\.locale, (AppLanguage(rawValue: appLanguageRaw) ?? .system).locale ?? Locale.autoupdatingCurrent)
        }
        .modelContainer(sharedModelContainer)
    }
}

/// Stands in for wingmark-backend's admin-curated `/api/species` catalog
/// until that endpoint is wired up, so the species search in Add Sighting
/// and the Guide tab have something to show.
private func seedSpeciesCatalogIfNeeded(in context: ModelContext) {
    let existingCount = (try? context.fetchCount(FetchDescriptor<Species>())) ?? 0
    guard existingCount == 0 else { return }

    let mockSpecies = [
        Species(
            commonName: "American Robin",
            scientificName: "Turdus migratorius",
            family: "Turdidae",
            order: "Passeriformes",
            speciesDescription: "A familiar backyard bird with a warm orange-red breast and a cheerful, whistled song.",
            lifespan: "2 years average in the wild",
            diet: "Earthworms, berries",
            habitat: "Lawns and gardens",
            sizeDescription: "~25cm wingspan",
            conservationStatus: "Least Concern",
            nativeRange: "North America"
        ),
        Species(
            commonName: "Blue Jay",
            scientificName: "Cyanocitta cristata",
            family: "Corvidae",
            order: "Passeriformes",
            speciesDescription: "A loud, intelligent songbird known for its blue, white, and black plumage and mimicry.",
            lifespan: "7 years average in the wild",
            diet: "Nuts, seeds, insects",
            habitat: "Deciduous and mixed forests",
            sizeDescription: "~34-43cm wingspan",
            conservationStatus: "Least Concern",
            nativeRange: "North America"
        ),
        Species(
            commonName: "House Sparrow",
            scientificName: "Passer domesticus",
            family: "Passeridae",
            order: "Passeriformes",
            speciesDescription: "A small, stocky bird closely tied to human settlements worldwide.",
            lifespan: "3 years average in the wild",
            diet: "Seeds, grains, insects",
            habitat: "Urban and suburban areas",
            sizeDescription: "~19-25cm wingspan",
            conservationStatus: "Least Concern",
            nativeRange: "Europe, introduced worldwide"
        ),
        Species(
            commonName: "Mourning Dove",
            scientificName: "Zenaida macroura",
            family: "Columbidae",
            order: "Columbiformes",
            speciesDescription: "A slender, long-tailed dove known for its soft, mournful cooing call.",
            lifespan: "1.5 years average in the wild",
            diet: "Seeds",
            habitat: "Open and semi-open areas",
            sizeDescription: "~37-45cm wingspan",
            conservationStatus: "Least Concern",
            nativeRange: "North America"
        ),
    ]

    for species in mockSpecies {
        context.insert(species)
    }
}
