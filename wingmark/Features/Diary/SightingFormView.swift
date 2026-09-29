import MapKit
import PhotosUI
import SwiftUI

struct SightingFormView: View {
    @Environment(DiaryStore.self) private var store
    let onSaved: (BirdLog) -> Void

    @State private var model: SightingFormModel
    @State private var pickerItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var showSpeciesPicker = false
    @State private var showLocationPicker = false
    @State private var isSaving = false
    @State private var dateError: String?
    @State private var speciesError: String?
    @State private var errorMessage: String?

    init(editing log: BirdLog?, onSaved: @escaping (BirdLog) -> Void) {
        self.onSaved = onSaved
        _model = State(initialValue: SightingFormModel(editing: log))
    }

    private var isCameraAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    var body: some View {
        Form {
            photoSection
            speciesSection
            detailsSection
            locationSection
            Section("Notes") {
                TextField("Custom name (optional)", text: $model.customName)
                TextField("Notes", text: $model.note, axis: .vertical)
                    .lineLimit(3...8)
            }
            if let errorMessage {
                Section { FieldError(message: errorMessage) }
            }
        }
        .navigationTitle(model.editing == nil ? "New Sighting" : "Edit Sighting")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if isSaving {
                    ProgressView()
                } else {
                    Button("Save", action: save)
                        .buttonStyle(.borderedProminent)
                        .disabled(!model.canSave)
                }
            }
        }
        .disabled(isSaving)
        .interactiveDismissDisabled(isSaving)
        .task { if model.editing == nil { await model.locateIfNeeded() } }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await model.loadPhoto(data: data)
                } else {
                    model.photoError = String(localized: "Couldn't read that photo.")
                }
                pickerItem = nil
            }
        }
        .onChange(of: model.observedAt) { dateError = nil }
        .sheet(isPresented: $showSpeciesPicker) {
            SpeciesPickerView { species in
                model.species = .init(id: species.id, name: species.name)
                model.dontKnowSpecies = false
                speciesError = nil
            }
        }
        .sheet(isPresented: $showLocationPicker) {
            LocationPickerView(initial: model.coordinate) { coordinate in
                Task { await model.setCoordinate(coordinate, source: .manual) }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                Task { await model.loadPhoto(image: image) }
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Sections

    private var photoSection: some View {
        Section {
            switch model.photo {
            case .none:
                EmptyView()
            case .existing(let path):
                RemoteImage(path: path, contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: 280)
                    .listRowInsets(EdgeInsets())
            case .new(let photo):
                Image(uiImage: photo.preview)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 280)
                    .listRowInsets(EdgeInsets())
            }
            if model.isProcessingPhoto {
                HStack { ProgressView(); Text("Reading photo…") }
            }
            PhotosPicker(selection: $pickerItem, matching: .images, preferredItemEncoding: .current) {
                Label(isPhotoEmpty ? "Choose Photo" : "Replace Photo", systemImage: "photo.on.rectangle")
            }
            if isCameraAvailable {
                Button("Take Photo", systemImage: "camera") { showCamera = true }
            }
            if !isPhotoEmpty {
                Button("Remove Photo", systemImage: "trash", role: .destructive) { model.removePhoto() }
            }
        } header: {
            Text("Photo")
        } footer: {
            if let error = model.photoError {
                FieldError(message: error)
            } else if isPhotoEmpty {
                Text("The photo's date and location fill in automatically when available.")
            }
        }
    }

    private var isPhotoEmpty: Bool {
        if case .none = model.photo { return true }
        return false
    }

    private var speciesSection: some View {
        Section {
            Toggle("I don't know the species", isOn: $model.dontKnowSpecies)
            if !model.dontKnowSpecies {
                Button {
                    showSpeciesPicker = true
                } label: {
                    LabeledContent("Species") {
                        Text(model.species?.name ?? String(localized: "Choose"))
                            .foregroundStyle(model.species == nil ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    }
                }
                .foregroundStyle(.primary)
                if model.species != nil {
                    Picker("Confidence", selection: $model.speciesStatus) {
                        ForEach(SpeciesStatus.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
            }
        } header: {
            Text("Species")
        } footer: {
            FieldError(message: speciesError)
        }
    }

    private var detailsSection: some View {
        Section {
            DatePicker("Seen", selection: $model.observedAt, in: ...Date.now)
            Picker("Life Stage", selection: $model.lifeStage) {
                ForEach(LifeStage.allCases) { Text($0.title).tag($0) }
            }
            Picker("Gender", selection: $model.gender) {
                ForEach(Gender.allCases) { Text($0.title).tag($0) }
            }
            Toggle("Pet", isOn: $model.pet)
        } header: {
            Text("Details")
        } footer: {
            FieldError(message: dateError)
        }
    }

    private var locationSection: some View {
        Section {
            if let coordinate = model.coordinate {
                Map(position: .constant(.region(MKCoordinateRegion(
                    center: coordinate, latitudinalMeters: 1000, longitudinalMeters: 1000
                ))), interactionModes: []) {
                    Marker("", systemImage: "bird.fill", coordinate: coordinate)
                }
                .frame(height: 150)
                .listRowInsets(EdgeInsets())
                .onTapGesture { showLocationPicker = true }
            }
            switch model.locationStatus {
            case .locating:
                HStack { ProgressView(); Text("Finding your location…") }
            case .failed(let message):
                FieldError(message: message)
            case .idle:
                EmptyView()
            }
            Button("Use Current Location", systemImage: "location") {
                Task { await model.useCurrentLocation() }
            }
            .disabled(model.locationStatus == .locating)
            Button(model.coordinate == nil ? "Pick on Map" : "Adjust on Map", systemImage: "map") {
                showLocationPicker = true
            }
            TextField("Place name (optional)", text: $model.locationName)
        } header: {
            Text("Location")
        } footer: {
            if model.coordinate == nil {
                Text("A location is required.")
            }
        }
    }

    // MARK: - Save

    private func save() {
        guard let input = model.makeInput() else { return }
        isSaving = true
        errorMessage = nil
        Task {
            defer { isSaving = false }
            do throws(APIError) {
                let saved = try await store.save(input, editing: model.editing, newPhoto: model.newPhoto)
                onSaved(saved)
            } catch {
                switch error.code {
                case .observedAtInFuture:
                    dateError = String(localized: "The sighting date can't be in the future.")
                case .invalidReference:
                    speciesError = String(localized: "That species is no longer available. Choose another.")
                    model.species = nil
                default:
                    errorMessage = error.userMessage
                }
            }
        }
    }
}

// MARK: - Species picker

struct SpeciesPickerView: View {
    @Environment(AuthSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    let onSelect: (Species) -> Void

    @State private var query = ""
    @State private var species: [Species] = []
    @State private var page = 0
    @State private var hasMore = true
    @State private var isLoading = false
    @State private var error: APIError?

    var body: some View {
        NavigationStack {
            List {
                ForEach(species) { item in
                    Button {
                        onSelect(item)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading) {
                            Text(item.name).foregroundStyle(.primary)
                            if let scientific = item.scientificName {
                                Text(scientific).font(.caption).italic().foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onAppear { if item.id == species.last?.id { Task { await loadMore() } } }
                }
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity)
                } else if let error, species.isEmpty {
                    ContentUnavailableView {
                        Label("Couldn't load species", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(error.userMessage)
                    } actions: {
                        Button("Try Again") { Task { await reload() } }
                    }
                } else if species.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
            .navigationTitle("Choose Species")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
            }
            .task(id: query) {
                if !query.isEmpty { try? await Task.sleep(for: .milliseconds(300)) }
                guard !Task.isCancelled else { return }
                await reload()
            }
        }
    }

    private func reload() async {
        page = 0
        hasMore = true
        species = []
        await loadMore()
    }

    private func loadMore() async {
        guard hasMore, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        let requestedQuery = query
        do throws(APIError) {
            let result = try await session.client.send(
                SpeciesAPI.list(search: requestedQuery, page: page, language: AppLanguage.current.resolvedCode)
            )
            guard requestedQuery == query else { return }
            species.append(contentsOf: result.content.filter { new in !species.contains { $0.id == new.id } })
            hasMore = result.hasMore
            page += 1
            error = nil
        } catch {
            if !error.isCancellation { self.error = error }
        }
    }
}

// MARK: - Location picker

struct LocationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let onPick: (CLLocationCoordinate2D) -> Void

    @State private var position: MapCameraPosition
    @State private var center: CLLocationCoordinate2D?

    init(initial: CLLocationCoordinate2D?, onPick: @escaping (CLLocationCoordinate2D) -> Void) {
        self.onPick = onPick
        _center = State(initialValue: initial)
        _position = State(initialValue: initial.map {
            .region(MKCoordinateRegion(center: $0, latitudinalMeters: 800, longitudinalMeters: 800))
        } ?? .userLocation(fallback: .automatic))
    }

    var body: some View {
        NavigationStack {
            Map(position: $position) {
                UserAnnotation()
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
            }
            .onMapCameraChange(frequency: .continuous) { context in
                center = context.region.center
            }
            .overlay {
                Image(systemName: "mappin")
                    .font(.largeTitle)
                    .foregroundStyle(.red)
                    .offset(y: -18)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .navigationTitle("Sighting Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if let center { onPick(center) }
                        dismiss()
                    }
                    .disabled(center == nil)
                }
            }
        }
    }
}

// MARK: - Camera

struct CameraPicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let onCapture: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker

        init(parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage { parent.onCapture(image) }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
