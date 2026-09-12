import SwiftUI
import SwiftData

struct RootTabView: View {
    var body: some View {
        TabView {
            MapView()
                .tabItem { Label("Map", systemImage: "map") }

            GuideView()
                .tabItem { Label("Guide", systemImage: "book") }

            ContentView()
                .tabItem { AddToDiaryTabIcon() }

            BadgesView()
                .tabItem { Label("Badges", systemImage: "trophy") }

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person") }
        }
        .tint(Theme.accent)
    }
}

#Preview {
    RootTabView()
        .modelContainer(for: BirdSighting.self, inMemory: true)
}
