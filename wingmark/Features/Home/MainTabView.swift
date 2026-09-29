import SwiftUI

struct MainTabView: View {
    @Environment(AuthSession.self) private var session
    @State private var diary: DiaryStore?

    var body: some View {
        if let diary {
            TabView {
                Tab("Map", systemImage: "map") {
                    PlaceholderTab(title: "Map", systemImage: "map")
                }
                Tab("Diary", systemImage: "book") {
                    DiaryView()
                }
                Tab("Badges", systemImage: "trophy") {
                    PlaceholderTab(title: "Badges", systemImage: "trophy")
                }
                Tab("Profile", systemImage: "person.crop.circle") {
                    ProfilePlaceholderView()
                }
                Tab("Guide", systemImage: "magnifyingglass", role: .search) {
                    PlaceholderTab(title: "Guide", systemImage: "magnifyingglass")
                }
            }
            .environment(diary)
        } else {
            ProgressView()
                .onAppear { diary = DiaryStore(session: session) }
        }
    }
}

private struct PlaceholderTab: View {
    let title: LocalizedStringKey
    let systemImage: String

    var body: some View {
        NavigationStack {
            ContentUnavailableView(title, systemImage: systemImage, description: Text("Coming soon."))
                .navigationTitle(title)
        }
    }
}

private struct ProfilePlaceholderView: View {
    @Environment(AuthSession.self) private var session

    var body: some View {
        NavigationStack {
            List {
                if let profile = session.profile {
                    LabeledContent("Name", value: profile.displayName)
                    LabeledContent("Username", value: profile.username)
                    LabeledContent("Email", value: profile.email)
                }
                Button("Log Out", role: .destructive) {
                    Task { await session.logOut() }
                }
            }
            .navigationTitle("Profile")
        }
    }
}
