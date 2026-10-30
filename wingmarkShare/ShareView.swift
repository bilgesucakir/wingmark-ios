import CoreLocation
import SwiftUI
import UniformTypeIdentifiers

struct ShareView: View {
    let context: NSExtensionContext?

    private enum Phase {
        case loading
        case ready(ProcessedPhoto)
        case failed
        case saved
    }

    @State private var phase = Phase.loading
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var uploadedPhotoUrl: String?
    @State private var requestKey = UUID()
    @State private var client = APIClient(tokenStore: SharedLoginStore())
    @State private var coordinate: CLLocationCoordinate2D?
    @State private var showSpeciesPicker = false
    @State private var cropped: ProcessedPhoto?
    @State private var cropRect = CropGeometry.full
    @State private var showCrop = false
    /// The form waits until the crop screen has been closed once, so it never flashes before it.
    @State private var cropDone = false
    @State private var dontKnowSpecies = false
    @State private var species: SpeciesChoice?
    @State private var speciesStatus = SpeciesStatus.confident
    @State private var seenNow = true
    @State private var observedAt = Date.now
    @State private var dateFromPhoto = false
    @State private var lifeStage = LifeStage.unknown
    @State private var gender = Gender.unknown
    @State private var pet = false
    @State private var isLocating = false
    @State private var locationIssue: PermissionIssue?
    @State private var locateFailed = false
    @State private var customName = ""
    @State private var locationName = ""
    @State private var suggestedPlaceName: String?
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .loading:
                    ProgressView()
                case .failed:
                    ContentUnavailableView("Couldn't read this photo", systemImage: "photo.badge.exclamationmark")
                case .saved:
                    ContentUnavailableView("Saved", systemImage: "checkmark.circle")
                case .ready(let photo):
                    if cropDone { form(photo) } else { ProgressView() }
                }
            }
            .navigationTitle("Wingmark")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { context?.cancelRequest(withError: CocoaError(.userCancelled)) }
                }
                if case .ready(let photo) = phase {
                    ToolbarItem(placement: .confirmationAction) {
                        if isSaving {
                            ProgressView()
                        } else {
                            Button("Save") { save(photo) }
                                .disabled(coordinate == nil)
                        }
                    }
                }
            }
        }
        .task { await load() }
        .environment(\.canOpenSettings, false)
        .fullScreenCover(isPresented: $showCrop, onDismiss: { cropDone = true }) {
            if case .ready(let photo) = phase {
                PhotoCropView(image: photo.preview, initial: cropRect) { rect in
                    cropRect = rect
                    uploadedPhotoUrl = nil
                    cropped = CropGeometry.isFull(rect) ? nil : PhotoProcessing.crop(photo, to: rect)
                }
            }
        }
        .sheet(isPresented: $showSpeciesPicker) {
            SpeciesPicker { species = $0 }
        }
        .task(id: coordinate.map { "\($0.latitude),\($0.longitude)" }) { await suggestPlaceName() }
    }

    private func form(_ photo: ProcessedPhoto) -> some View {
        List {
            Section {
                Image(uiImage: (cropped ?? photo).preview)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 280)
                    .listRowInsets(EdgeInsets())
            } header: {
                Text("Photo")
            }
            Section {
                Toggle("I don't know the species", isOn: $dontKnowSpecies)
                if !dontKnowSpecies {
                    Button { showSpeciesPicker = true } label: {
                        LabeledContent("Species") {
                            Text(species?.name ?? String(localized: "Choose", bundle: .app)).foregroundStyle(species == nil ? .secondary : .primary)
                        }
                    }
                    .foregroundStyle(.primary)
                    if species != nil {
                        Picker("Confidence", selection: $speciesStatus) {
                            ForEach(SpeciesStatus.allCases) { Text($0.title).tag($0) }
                        }
                    }
                }
            } header: {
                Text("Species")
            }
            Section {
                Toggle("Seen now", isOn: $seenNow.animation())
                if !seenNow {
                    DatePicker("Seen", selection: $observedAt, in: ...Date.now)
                }
                Picker("Life Stage", selection: $lifeStage) {
                    ForEach(LifeStage.allCases) { Text($0.title).tag($0) }
                }
                Picker("Gender", selection: $gender) {
                    ForEach(Gender.allCases) { Text($0.title).tag($0) }
                }
                Toggle("Pet", isOn: $pet)
            } header: {
                Text("Details")
            } footer: {
                if dateFromPhoto, !seenNow {
                    Label("Date taken from the photo. You can change it.", systemImage: "photo")
                }
            }
            Section {
                if isLocating {
                    HStack { ProgressView(); Text("Finding your location…") }
                } else if let coordinate {
                    LabeledContent("Location") { Text(coordinate.formattedCoordinates) }
                }
                Button("Use Current Location", systemImage: "location") { Task { await useCurrentLocation() } }
                    .disabled(isLocating)
                TextField("Place name (optional)", text: $locationName)
            } header: {
                Text("Location")
            } footer: {
                if coordinate == nil, !isLocating {
                    Text("A location is required.")
                }
            }
            Section {
                TextField("Custom name (optional)", text: $customName)
                TextField("Notes", text: $note, axis: .vertical)
            } header: {
                Text("Notes")
            }
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            }
        }
        .disabled(isSaving)
        .permissionAlert($locationIssue)
        .alert("Couldn't find your location", isPresented: $locateFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Move the map to the spot, or try again.")
        }
    }

    private func useCurrentLocation() async {
        isLocating = true
        defer { isLocating = false }
        await LocationService.requestAccessIfNeeded()
        do throws(LocationError) {
            coordinate = try await LocationService.currentLocation().coordinate
        } catch {
            if error == .denied {
                let restricted = CLLocationManager().authorizationStatus == .restricted
                locationIssue = PermissionIssue(kind: .location, state: restricted ? .restricted : .notAllowed)
            } else {
                locateFailed = true
            }
        }
    }

    private func load() async {
        guard let provider = context?.inputItems.compactMap({ ($0 as? NSExtensionItem)?.attachments }).flatMap({ $0 }).first(where: { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }),
              let data = await Self.data(from: provider),
              let photo = PhotoProcessing.process(data)
        else {
            phase = .failed
            return
        }
        coordinate = photo.metadata.coordinate
        showCrop = true
        if let captured = photo.metadata.capturedAt {
            seenNow = false
            observedAt = min(captured, .now)
            dateFromPhoto = true
        }
        phase = .ready(photo)
        if coordinate == nil { await locateQuietly() }
    }

    /// For a photo without a place: uses where the person is now, but only when location is already allowed, so nothing
    /// pops up before they have seen the form. Otherwise the Location section asks for it.
    private func locateQuietly() async {
        guard [.authorizedWhenInUse, .authorizedAlways].contains(CLLocationManager().authorizationStatus) else { return }
        isLocating = true
        defer { isLocating = false }
        if let location = try? await LocationService.currentLocation(timeout: .seconds(10)), coordinate == nil {
            coordinate = location.coordinate
        }
    }

    /// Reads the file in place instead of loading a full-size image into memory.
    private static func data(from provider: NSItemProvider) async -> Data? {
        await withCheckedContinuation { continuation in
            provider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, _ in
                continuation.resume(returning: url.flatMap { try? Data(contentsOf: $0, options: .mappedIfSafe) })
            }
        }
    }

    /// Fills the place name from the coordinates, unless the person already typed their own.
    private func suggestPlaceName() async {
        guard let coordinate, locationName.isEmpty || locationName == suggestedPlaceName else { return }
        guard let name = await LocationService.placeName(for: coordinate) else { return }
        if locationName.isEmpty || locationName == suggestedPlaceName {
            suggestedPlaceName = name
            locationName = name
        }
    }

    /// Uploads the photo once, then creates the sighting. A retry after a failure reuses the photo and the key.
    private func save(_ photo: ProcessedPhoto) {
        guard let coordinate, !isSaving else { return }
        isSaving = true
        errorMessage = nil
        Task {
            defer { isSaving = false }
            guard client.tokenStore.load() != nil else {
                errorMessage = String(localized: "Open Wingmark and log in, then try again.", bundle: .app)
                return
            }
            let seen = seenNow ? Date.now : min(observedAt, .now)
            let chosen = dontKnowSpecies ? nil : species
            do throws(APIError) {
                if uploadedPhotoUrl == nil {
                    uploadedPhotoUrl = try await client.send(UploadAPI.photo(jpeg: (cropped ?? photo).jpeg)).url
                }
                let input = BirdLogInput(
                    speciesId: chosen?.id, speciesStatus: chosen == nil ? nil : speciesStatus, pet: pet,
                    customName: Self.nonEmpty(customName), lifeStage: lifeStage, gender: gender,
                    photoUrl: uploadedPhotoUrl, note: Self.nonEmpty(note),
                    latitude: coordinate.latitude, longitude: coordinate.longitude,
                    locationName: Self.nonEmpty(locationName), observedAt: seen,
                    utcOffsetMinutes: TimeZone.current.secondsFromGMT(for: seen) / 60
                )
                _ = try await client.send(BirdLogAPI.create(input, idempotencyKey: requestKey))
                phase = .saved
                try? await Task.sleep(for: .seconds(1))
                context?.completeRequest(returningItems: nil)
            } catch {
                if case .sessionExpired = error {
                    errorMessage = String(localized: "Open Wingmark and log in, then try again.", bundle: .app)
                } else {
                    errorMessage = error.userMessage
                }
            }
        }
    }

    private static func nonEmpty(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct SpeciesChoice: Equatable {
    let id: UUID
    let name: String
}

/// Searches the public species list. It needs a connection; without one the person can add the species later in the app.
private struct SpeciesPicker: View {
    let onSelect: (SpeciesChoice) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [Species] = []
    @State private var isLoading = false
    @State private var failed = false
    private let client = APIClient(tokenStore: InMemoryTokenStore())

    var body: some View {
        NavigationStack {
            List {
                ForEach(results) { species in
                    Button {
                        onSelect(SpeciesChoice(id: species.id, name: species.name))
                        dismiss()
                    } label: {
                        VStack(alignment: .leading) {
                            Text(species.name).foregroundStyle(.primary)
                            if let scientific = species.scientificName {
                                Text(scientific).font(.caption).italic().foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity)
                } else if failed {
                    ContentUnavailableView {
                        Label("Couldn't load species", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text("You can add the species later in the Wingmark app.")
                    } actions: {
                        Button("Try Again") { Task { await search() } }
                    }
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("Search by common or scientific name"))
            .navigationTitle("Choose Species")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
            }
            .task(id: query) {
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                await search()
            }
        }
    }

    private func search() async {
        isLoading = true
        failed = false
        defer { isLoading = false }
        do throws(APIError) {
            let page = try await client.send(SpeciesAPI.list(search: query, page: 0, size: 30, language: client.language))
            results = page.content
        } catch {
            if !error.isCancellation { failed = true }
        }
    }
}
