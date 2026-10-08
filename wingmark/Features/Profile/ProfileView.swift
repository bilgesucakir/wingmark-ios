import SwiftUI

struct ProfileView: View {
    @Environment(AuthSession.self) private var session
    @Environment(DiaryStore.self) private var diary

    @State private var allLogs: [BirdLog] = []
    @State private var showEditProfile = false
    @State private var favoritePhotoPath: String?
    @SceneStorage("profile.settingsOpen") private var settingsOpen = false

    private var distinctSpecies: Int { Set(allLogs.compactMap(\.speciesId)).count }

    var body: some View {
        NavigationStack(path: settingsPath) {
            List {
                if let profile = session.profile {
                    header(profile)
                    Section {
                        LabeledContent("First Name", value: profile.firstName.nonEmptyOrDash)
                        LabeledContent("Last Name", value: profile.lastName.nonEmptyOrDash)
                        LabeledContent("Username", value: profile.username)
                        LabeledContent("Email", value: profile.email)
                        if let createdAt = profile.createdAt {
                            LabeledContent("Member Since") { Text(createdAt, format: .dateTime.day().month(.wide).year()) }
                        }
                    }
                    Section("Stats") {
                        LabeledContent("Sightings", value: allLogs.count, format: .number)
                        LabeledContent("Species Seen", value: distinctSpecies, format: .number)
                        if favoritePhotoPath == nil {
                            LabeledContent("Favorite Species", value: profile.favoriteSpeciesName.nonEmptyOrDash)
                        }
                    }
                    if let favoritePhotoPath {
                        Section("Favorite Species") {
                            RemoteImage(path: favoritePhotoPath)
                                .frame(maxWidth: .infinity)
                                .frame(height: 200)
                                .clipped()
                                .listRowInsets(EdgeInsets())
                                .accessibilityHidden(true)
                            Text(profile.favoriteSpeciesName.nonEmptyOrDash)
                                .font(.headline)
                        }
                    }
                } else {
                    Section {
                        HStack { ProgressView(); Text("Loading profile…") }
                    }
                }

                Section {
                    NavigationLink(value: ProfileRoute.settings) {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationDestination(for: ProfileRoute.self) { _ in SettingsView() }
            .toolbar {
                if session.profile != nil {
                    Button("Edit") { showEditProfile = true }
                }
            }
            .sheet(isPresented: $showEditProfile) {
                if let profile = session.profile {
                    EditProfileView(profile: profile)
                }
            }
            .refreshable { await reload() }
            .task(id: diary.revision) { await loadStats() }
            .task(id: session.profile?.favoriteSpeciesId) { await loadFavoritePhoto() }
            .task { if session.profile == nil { await session.refreshProfile() } }
        }
    }

    /// Kept in scene storage so Settings stays open when a language change rebuilds the tabs.
    private var settingsPath: Binding<[ProfileRoute]> {
        Binding(
            get: { settingsOpen ? [.settings] : [] },
            set: { settingsOpen = $0.contains(.settings) }
        )
    }

    private func header(_ profile: UserProfile) -> some View {
        Section {
            HStack(spacing: 16) {
                AvatarView(profilePicture: profile.profilePicture, size: 72)
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.displayName)
                        .font(.title2.bold())
                    Text("@\(profile.username)")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func reload() async {
        await session.refreshProfile()
        await loadStats()
    }

    private func loadFavoritePhoto() async {
        guard let id = session.profile?.favoriteSpeciesId else {
            favoritePhotoPath = nil
            return
        }
        let species = try? await session.client.send(SpeciesAPI.species(id: id))
        favoritePhotoPath = species?.images?.first?.imageUrl
    }

    private func loadStats() async {
        guard let userId = session.userId,
              let logs = try? await session.client.send(BirdLogAPI.userLogs(userId: userId, filter: DiaryFilter()))
        else { return }
        allLogs = logs
    }
}

private extension Optional where Wrapped == String {
    var nonEmptyOrDash: String {
        guard let value = self?.trimmingCharacters(in: .whitespaces), !value.isEmpty else { return "—" }
        return value
    }
}

enum ProfileRoute: Hashable {
    case settings
}
