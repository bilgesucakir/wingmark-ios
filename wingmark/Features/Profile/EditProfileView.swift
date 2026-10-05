import PhotosUI
import SwiftUI

struct EditProfileView: View {
    @Environment(AuthSession.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var firstName: String
    @State private var lastName: String
    @State private var profilePicture: String?
    @State private var newPhoto: ProcessedPhoto?
    @State private var favoriteSpecies: SightingFormModel.SpeciesChoice?
    @State private var avatarKeys = AvatarPresets.fallbackKeys
    @State private var pickerItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var cameraIssue: PermissionIssue?
    @State private var showSpeciesPicker = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let original: UserProfile

    init(profile: UserProfile) {
        original = profile
        _firstName = State(initialValue: profile.firstName ?? "")
        _lastName = State(initialValue: profile.lastName ?? "")
        _profilePicture = State(initialValue: profile.profilePicture)
        _favoriteSpecies = State(initialValue: profile.favoriteSpeciesId.map {
            .init(id: $0, name: profile.favoriteSpeciesName ?? "")
        })
    }

    var body: some View {
        NavigationStack {
            Form {
                avatarSection
                Section("Name") {
                    TextField("First Name", text: $firstName)
                        .textContentType(.givenName)
                    TextField("Last Name", text: $lastName)
                        .textContentType(.familyName)
                }
                Section("Favorite Species") {
                    Button {
                        showSpeciesPicker = true
                    } label: {
                        LabeledContent("Species") {
                            Text(favoriteSpecies?.name ?? String(localized: "None", bundle: .app))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                    if favoriteSpecies != nil {
                        Button("Clear Favorite", role: .destructive) { favoriteSpecies = nil }
                    }
                }
                if let errorMessage {
                    Section { FieldError(message: errorMessage) }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save", action: save)
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
            .disabled(isSaving)
            .interactiveDismissDisabled(isSaving)
            .task { await loadAvatarKeys() }
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let photo = await Task.detached(operation: { PhotoProcessing.process(data) }).value {
                        newPhoto = photo
                    } else {
                        errorMessage = String(localized: "Couldn't read that photo.", bundle: .app)
                    }
                    pickerItem = nil
                }
            }
            .sheet(isPresented: $showSpeciesPicker) {
                SpeciesPickerView { species in
                    favoriteSpecies = .init(id: species.id, name: species.name)
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { image in
                    Task {
                        newPhoto = await Task.detached(operation: { PhotoProcessing.process(image) }).value
                    }
                }
                .ignoresSafeArea()
            }
            .permissionAlert($cameraIssue)
        }
    }

    private func openCamera() async {
        switch await CameraAccess.resolve() {
        case .open: showCamera = true
        case .blocked(let issue): cameraIssue = issue
        }
    }

    @ViewBuilder
    private var avatarSection: some View {
        // The preview is its own section so the choices below get a card with rounded corners on every side.
        // As the first row of that card, a transparent preview left the card with a flat, unfinished top edge.
        Section {
            HStack {
                Spacer()
                Group {
                    if let newPhoto {
                        Image(uiImage: newPhoto.preview)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 96, height: 96)
                            .clipShape(.circle)
                    } else {
                        AvatarView(profilePicture: profilePicture, size: 96)
                    }
                }
                Spacer()
            }
            .listRowBackground(Color.clear)
        } header: {
            Text("Profile Picture")
        }
        .listSectionSpacing(.compact)

        Section {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                ForEach(avatarKeys, id: \.self) { key in
                    Button {
                        profilePicture = key
                        newPhoto = nil
                    } label: {
                        AvatarView(profilePicture: key, size: 60)
                            .overlay {
                                if profilePicture == key && newPhoto == nil {
                                    Circle().strokeBorder(.tint, lineWidth: 3)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Avatar \(key.dropFirst("avatar-".count))"))
                }
            }
            .padding(.vertical, 4)

            PhotosPicker(selection: $pickerItem, matching: .images, preferredItemEncoding: .current) {
                Label("Use My Photo", systemImage: "photo.on.rectangle")
            }
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take Photo", systemImage: "camera") { Task { await openCamera() } }
            }
            if profilePicture != nil || newPhoto != nil {
                Button("Remove Photo", systemImage: "trash", role: .destructive) {
                    profilePicture = nil
                    newPhoto = nil
                }
            }
        }
    }

    private func loadAvatarKeys() async {
        if let avatars = try? await session.client.send(AuthAPI.avatars()), !avatars.isEmpty {
            avatarKeys = avatars.map(\.key)
        }
    }

    private func save() {
        isSaving = true
        errorMessage = nil
        Task {
            defer { isSaving = false }
            do throws(APIError) {
                var update = AuthAPI.ProfileUpdate(original)
                update.firstName = Self.nonEmpty(firstName)
                update.lastName = Self.nonEmpty(lastName)
                update.favoriteSpeciesId = favoriteSpecies?.id
                if let newPhoto {
                    update.profilePicture = try await session.client.send(UploadAPI.photo(jpeg: newPhoto.jpeg)).url
                } else {
                    update.profilePicture = profilePicture
                }
                try await session.updateProfile(update)
                dismiss()
            } catch {
                switch error.code {
                case .invalidReference:
                    errorMessage = String(localized: "That species is no longer available. Choose another.", bundle: .app)
                    favoriteSpecies = nil
                default:
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
