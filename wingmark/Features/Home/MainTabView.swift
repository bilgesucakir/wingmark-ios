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
                Tab("Guide", systemImage: "text.book.closed") {
                    PlaceholderTab(title: "Guide", systemImage: "text.book.closed")
                }
                Tab("Diary", systemImage: "book") {
                    DiaryView()
                }
                Tab("Badges", systemImage: "trophy") {
                    PlaceholderTab(title: "Badges", systemImage: "trophy")
                }
                Tab("Profile", systemImage: "person.crop.circle") {
                    ProfileView()
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
