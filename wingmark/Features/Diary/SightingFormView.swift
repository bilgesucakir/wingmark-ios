import MapKit
import PhotosUI
import SwiftUI
import TipKit

struct SightingFormView: View {
    @Environment(DiaryStore.self) private var store
    let onSaved: (BirdLog) -> Void

    @State private var model: SightingFormModel
    @State private var pickerItem: PhotosPickerItem?
    @State private var showCamera = false
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
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await model.loadPhoto(data: data)
                } else {
                    model.photoError = String(localized: "Couldn't read that photo.", bundle: .app)
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
        .permissionAlert($cameraIssue)
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
            .popoverTip(PhotoPrefillTip(), arrowEdge: .top)
            .onChange(of: pickerItem) { PhotoPrefillTip().invalidate(reason: .actionPerformed) }
            if isCameraAvailable {
                Button("Take Photo", systemImage: "camera") {
                    PhotoPrefillTip().invalidate(reason: .actionPerformed)
                    Task { await openCamera() }
                }
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
        .searchable(text: $search.query, placement: .navigationBarDrawer(displayMode: .always))
        .task { await search.loadIfNeeded() }
    }
}

// MARK: - Location picker

struct LocationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let onPick: (CLLocationCoordinate2D) -> Void

    @State private var position: MapCameraPosition
    @State private var center: CLLocationCoordinate2D?
    @State private var isMoving = false
    @State private var placeName: String?
    @State private var locating = false
    @State private var locationError: String?
    private let hasInitial: Bool

    init(initial: CLLocationCoordinate2D?, onPick: @escaping (CLLocationCoordinate2D) -> Void) {
        self.onPick = onPick
        hasInitial = initial != nil
        _center = State(initialValue: initial)
        _position = State(initialValue: initial.map {
            .region(MKCoordinateRegion(center: $0, latitudinalMeters: 800, longitudinalMeters: 800))
        } ?? .automatic)
    }

    var body: some View {
        NavigationStack {
            Map(position: $position) {
                UserAnnotation()
            }
            .mapControls {
                MapCompass()
            }
            .onMapCameraChange(frequency: .continuous) { context in
                center = context.region.center
                isMoving = true
            }
            .onMapCameraChange(frequency: .onEnd) { context in
                center = context.region.center
                isMoving = false
            }
            .overlay { CenterPin(isLifted: isMoving).allowsHitTesting(false) }
            .safeAreaInset(edge: .bottom) { bottomCard }
            .navigationTitle("Sighting Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
            }
            .task { if !hasInitial { await locate() } }
            .task(id: roundedCenter) { await lookUpPlaceName() }
        }
    }

    private var bottomCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    if locating {
                        Label("Finding your location…", systemImage: "location")
                            .foregroundStyle(.secondary)
                    } else if let locationError {
                        Text(locationError)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(placeName ?? String(localized: "Move the map to place the pin", bundle: .app))
                            .font(.headline)
                            .lineLimit(2)
                        if let center {
                            Text(center.formattedCoordinates)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer()
                Button {
                    Task { await locate() }
                } label: {
                    Image(systemName: "location.fill")
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .disabled(locating)
                .accessibilityLabel(Text("Use Current Location"))
            }
            Button {
                if let center { onPick(center) }
                dismiss()
            } label: {
                Text("Use This Location").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(center == nil || isMoving)
        }
        .padding(16)
        .background(.regularMaterial, in: .rect(cornerRadius: 24))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private var roundedCenter: String? {
        guard !isMoving, let center else { return nil }
        return String(format: "%.4f,%.4f", center.latitude, center.longitude)
    }

    private func locate() async {
        locating = true
        locationError = nil
        defer { locating = false }
        do throws(LocationError) {
            let location = try await LocationService.currentLocation()
            withAnimation {
                position = .region(MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 800, longitudinalMeters: 800))
            }
            center = location.coordinate
        } catch {
            locationError = error == .denied
                ? String(localized: "Location access is off. Allow it in Settings or move the map to the spot.", bundle: .app)
                : String(localized: "Couldn't find your location. Move the map to the spot.", bundle: .app)
        }
    }

    private func lookUpPlaceName() async {
        guard let center, !isMoving else { return }
        try? await Task.sleep(for: .milliseconds(250))
        guard !Task.isCancelled else { return }
        placeName = await LocationService.placeName(for: center)
    }
}

private struct CenterPin: View {
    let isLifted: Bool

    var body: some View {
        ZStack {
            Ellipse()
                .fill(.black.opacity(0.25))
                .frame(width: isLifted ? 14 : 10, height: 5)
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(.tint)
                        .frame(width: 44, height: 44)
                    Image(systemName: "bird.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .overlay { Circle().strokeBorder(.white, lineWidth: 3) }
                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                Rectangle()
                    .fill(.tint)
                    .frame(width: 3, height: 14)
            }
            .offset(y: isLifted ? -38 : -29)
        }
        .animation(.snappy(duration: 0.2), value: isLifted)
        .accessibilityHidden(true)
    }
}

private extension CLLocationCoordinate2D {
    var formattedCoordinates: String {
        String(format: "%.5f, %.5f", latitude, longitude)
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
