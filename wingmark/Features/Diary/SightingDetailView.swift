import MapKit
import SwiftUI

struct SightingDetailView: View {
    @Environment(DiaryStore.self) private var store
    let logId: UUID
    @Binding var path: [DiaryRoute]

    @State private var confirmDelete = false
    @State private var errorMessage: String?
    @State private var isDeleting = false
    @State private var isSavingPhoto = false
    @State private var photoIssue: PermissionIssue?
    @State private var saveOutcome: PhotoSaveOutcome?

    var body: some View {
        Group {
            if let log = store.log(id: logId) {
                content(log)
            } else {
                ContentUnavailableView("This sighting no longer exists.", systemImage: "bird")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.refresh(logId) }
        .permissionAlert($photoIssue)
        .alert(saveOutcome?.title ?? "", isPresented: Binding(get: { saveOutcome != nil }, set: { if !$0 { saveOutcome = nil } }),
               presenting: saveOutcome) { _ in
            Button("OK", role: .cancel) {}
        } message: { outcome in
            Text(outcome.message)
        }
        .sensoryFeedback(.success, trigger: saveOutcome == .saved)
    }

    private func content(_ log: BirdLog) -> some View {
        List {
            if log.photoUrl != nil {
                Section {
                    RemoteImage(path: log.photoUrl, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel(Text("Photo of \(log.displayName)"))
                        .accessibilityAddTraits(.isImage)
                        .traitChips(lifeStage: log.lifeStage, gender: log.gender)
                        .listRowInsets(EdgeInsets())
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(log.displayName)
                        .font(.title2.bold())
                    if log.customName != nil, let species = log.speciesCommonName {
                        Text(species).foregroundStyle(.secondary)
                    }
                }
                LabeledContent("Seen") { Text(log.observedAt, format: .dateTime.day().month(.wide).year().hour().minute()) }
                if log.speciesId != nil, let status = log.speciesStatus {
                    LabeledContent("Identification", value: status.title)
                }
                LabeledContent("Life Stage", value: log.lifeStage.title)
                LabeledContent("Gender", value: log.gender.title)
                if log.pet {
                    LabeledContent("Pet", value: String(localized: "Yes", bundle: .app))
                }
            }

            if log.hasLocation || !(log.locationName ?? "").isEmpty {
            Section("Location") {
                if log.hasLocation {
                let coordinate = CLLocationCoordinate2D(latitude: log.latitude, longitude: log.longitude)
                Map(initialPosition: .region(MKCoordinateRegion(
                    center: coordinate, latitudinalMeters: 1500, longitudinalMeters: 1500
                )), interactionModes: []) {
                    Marker(log.displayName, systemImage: "bird.fill", coordinate: coordinate)
                }
                .frame(height: 180)
                .listRowInsets(EdgeInsets())
                }
                if let place = log.locationName, !place.isEmpty {
                    Text(place)
                }
                if let meters = UserLocation.shared.distance(to: log) {
                    Label(UnitPreference.device.distanceAway(meters: meters), systemImage: "location")
                        .foregroundStyle(.secondary)
                }
            }
            }

            if let note = log.note, !note.isEmpty {
                Section("Notes") {
                    Text(note)
                }
            }

            Section {
                Button("Delete Sighting", role: .destructive) { confirmDelete = true }
                    .disabled(isDeleting)
                    .confirmationDialog("Delete this sighting?", isPresented: $confirmDelete, titleVisibility: .visible) {
                        Button("Delete", role: .destructive) { delete(log) }
                    } message: {
                        Text("This can't be undone.")
                    }
            } footer: {
                FieldError(message: errorMessage)
            }
        }
        .toolbar {
            if log.photoUrl != nil {
                ToolbarItem {
                    Button("Save Photo", systemImage: "square.and.arrow.down") { savePhoto(log) }
                        .disabled(isSavingPhoto)
                }
            }
            ToolbarItem { Button("Edit") { path.append(.edit(log.id)) } }
        }
    }

    private func savePhoto(_ log: BirdLog) {
        isSavingPhoto = true
        Task {
            defer { isSavingPhoto = false }
            switch await PhotoSaver().save(path: log.photoUrl) {
            case .saved: saveOutcome = .saved
            case .blocked(let issue): photoIssue = issue
            case .failed: saveOutcome = .failed
            }
        }
    }

    private func delete(_ log: BirdLog) {
        isDeleting = true
        errorMessage = nil
        Task {
            defer { isDeleting = false }
            do throws(APIError) {
                try await store.delete(log)
                path.removeAll { $0 == .detail(log.id) }
            } catch {
                errorMessage = error.userMessage
            }
        }
    }
}

private enum PhotoSaveOutcome {
    case saved, failed

    var title: String {
        switch self {
        case .saved: String(localized: "Photo saved", bundle: .app)
        case .failed: String(localized: "Couldn't save the photo", bundle: .app)
        }
    }

    var message: String {
        switch self {
        case .saved: String(localized: "The photo is now in your Photos library.", bundle: .app)
        case .failed: String(localized: "Check your connection and try again.", bundle: .app)
        }
    }
}
