import MapKit
import PhotosUI
import SwiftUI

struct SightingFormView: View {
    @Environment(DiaryStore.self) private var store
    let onSaved: (BirdLog) -> Void

    @State private var model: SightingFormModel
    @State private var pickerItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var showCrop = false
    /// True from choosing a photo until the crop screen is up, so the form never shows in between.
    @State private var isPreparingPhoto = false
    @State private var cameraIssue: PermissionIssue?
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
            isPreparingPhoto = true
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await model.loadPhoto(data: data)
                } else {
                    model.photoError = String(localized: "Couldn't read that photo.", bundle: .app)
                }
                openCropOrShowForm()
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
                isPreparingPhoto = true
                Task {
                    await model.loadPhoto(image: image)
                    openCropOrShowForm()
                }
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showCrop) {
            if let original = model.uncroppedPhoto {
                PhotoCropView(image: original.preview, initial: model.cropRect) { rect in
                    Task { await model.applyCrop(rect) }
                }
                .onAppear { isPreparingPhoto = false }
            }
        }
        .overlay {
            if isPreparingPhoto {
                ZStack {
                    Color.black.ignoresSafeArea()
                    ProgressView().tint(.white)
                }
            }
        }
        .toolbar(isPreparingPhoto ? .hidden : .automatic, for: .navigationBar)
        .toolbar(isPreparingPhoto ? .hidden : .automatic, for: .tabBar)
        .permissionAlert($cameraIssue)
    }

    private func openCropOrShowForm() {
        if model.uncroppedPhoto != nil, model.photoError == nil {
            showCrop = true
        } else {
            isPreparingPhoto = false
        }
    }

    private func openCamera() async {
        switch await CameraAccess.resolve() {
        case .open: showCamera = true
        case .blocked(let issue): cameraIssue = issue
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
                    .traitChips(lifeStage: model.lifeStage, gender: model.gender)
                    .listRowInsets(EdgeInsets())
            case .new(let photo):
                Image(uiImage: photo.preview)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 280)
                    .traitChips(lifeStage: model.lifeStage, gender: model.gender)
                    .listRowInsets(EdgeInsets())
            }
            if model.isProcessingPhoto {
                HStack { ProgressView(); Text("Reading photo…") }
            }
            // Read before the picker: its label closure can't touch main-actor state directly.
            let photoIsEmpty = isPhotoEmpty
            PhotosPicker(selection: $pickerItem, matching: .images, preferredItemEncoding: .current) {
                Label(photoIsEmpty ? "Choose Photo" : "Replace Photo", systemImage: "photo.on.rectangle")
            }
            if isCameraAvailable {
                Button("Take Photo", systemImage: "camera") {
                    Task { await openCamera() }
                }
            }
            if !isPhotoEmpty {
                Button("Remove Photo", systemImage: "trash", role: .destructive) { model.removePhoto() }
                    .foregroundStyle(.red)
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
                        Text(model.species?.name ?? String(localized: "Choose", bundle: .app))
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
            Toggle("Seen now", isOn: $model.seenNow.animation())
            if !model.seenNow {
                DatePicker("Seen", selection: $model.observedAt, in: ...Date.now)
            }
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
            if let dateError {
                FieldError(message: dateError)
            } else if model.dateFromPhoto && !model.seenNow {
                Label("Date taken from the photo. You can change it.", systemImage: "photo")
            }
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
                // "Adjust on Map" below does the same for VoiceOver and keyboard users.
                .accessibilityHidden(true)
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
                    dateError = String(localized: "The sighting date can't be in the future.", bundle: .app)
                case .invalidReference:
                    speciesError = String(localized: "That species is no longer available. Choose another.", bundle: .app)
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

    @State private var search: SpeciesSearch?

    var body: some View {
        NavigationStack {
            Group {
                if let search {
                    SpeciesPickerList(search: search) { species in
                        onSelect(species)
                        dismiss()
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Choose Species")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
            }
        }
        .onAppear { if search == nil { search = SpeciesSearch(client: session.client) } }
    }
}

private struct SpeciesPickerList: View {
    @Bindable var search: SpeciesSearch
    let onSelect: (Species) -> Void
    @FocusState private var searchFocused: Bool

    var body: some View {
        List {
            ForEach(search.results) { species in
                Button {
                    onSelect(species)
                } label: {
                    VStack(alignment: .leading) {
                        Text(species.name).foregroundStyle(.primary)
                        if let scientific = species.scientificName {
                            Text(scientific).font(.caption).italic().foregroundStyle(.secondary)
                        }
                    }
                }
                .task { await search.loadMoreIfNeeded(after: species) }
            }
            if search.isLoading {
                ProgressView().frame(maxWidth: .infinity)
            } else if let error = search.error, search.results.isEmpty {
                ContentUnavailableView {
                    Label("Couldn't load species", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(error.userMessage)
                } actions: {
                    Button("Try Again") { Task { await search.reload() } }
                }
            } else if search.results.isEmpty, search.hasLoaded {
                ContentUnavailableView.search(text: search.query)
            }
        }
        .searchable(text: $search.query, placement: .navigationBarDrawer(displayMode: .always),
                    prompt: Text("Search by common or scientific name"))
        .searchFocused($searchFocused)
        .onAppear { searchFocused = true }
        .task { await search.loadIfNeeded() }
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
