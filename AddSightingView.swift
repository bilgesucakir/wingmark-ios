import SwiftUI
import SwiftData

struct AddSightingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Species.commonName) private var allSpecies: [Species]

    @State private var date = Date.now
    @State private var locationName = ""
    @State private var speciesSearch = ""
    @State private var selectedSpecies: Species?
    @State private var doesNotKnowSpecies = false
    @State private var lifeStage: LifeStage = .adult
    @State private var notes = ""

    private var matchingSpecies: [Species] {
        guard !speciesSearch.isEmpty else { return allSpecies }
        return allSpecies.filter { $0.commonName.localizedCaseInsensitiveContains(speciesSearch) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("When & Where") {
                    DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    TextField("Location", text: $locationName)
                }

                Section("Species") {
                    if !doesNotKnowSpecies {
                        TextField("Search species...", text: $speciesSearch)
                        ForEach(matchingSpecies) { species in
                            Button {
                                selectedSpecies = species
                                speciesSearch = species.commonName
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(species.commonName)
                                            .foregroundStyle(Theme.textPrimary)
                                        Text(species.scientificName)
                                            .font(.caption)
                                            .italic()
                                            .foregroundStyle(Theme.textSecondary)
                                    }
                                    Spacer()
                                    if selectedSpecies?.id == species.id {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(Theme.accent)
                                    }
                                }
                            }
                        }
                    }
                    Toggle("I don't know — that's okay", isOn: $doesNotKnowSpecies.animation())
                        .onChange(of: doesNotKnowSpecies) { _, newValue in
                            if newValue { selectedSpecies = nil }
                        }
                }

                Section("Life Stage") {
                    Picker("Life Stage", selection: $lifeStage) {
                        Text(LifeStage.adult.label).tag(LifeStage.adult)
                        Text(LifeStage.baby.label).tag(LifeStage.baby)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("New Sighting")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
        }
    }

    private func save() {
        let sighting = BirdSighting(
            date: date,
            placeName: locationName.isEmpty ? nil : locationName,
            lifeStage: lifeStage,
            notes: notes.isEmpty ? nil : notes,
            species: doesNotKnowSpecies ? nil : selectedSpecies,
            speciesStatus: (doesNotKnowSpecies || selectedSpecies == nil) ? nil : .confident
        )
        modelContext.insert(sighting)
        dismiss()
    }
}

#Preview {
    AddSightingView()
        .modelContainer(for: BirdSighting.self, inMemory: true)
}
