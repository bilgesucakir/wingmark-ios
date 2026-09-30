import SwiftUI

struct MainTabView: View {
    @Environment(AuthSession.self) private var session
    @State private var diary: DiaryStore?
    @State private var map: MapStore?
    @State private var badges: BadgesStore?

    var body: some View {
        if let diary, let map, let badges {
            TabView {
                Tab("Map", systemImage: "map") {
                    SightingsMapView()
                }
                Tab("Guide", systemImage: "text.book.closed") {
                    GuideView()
                }
                Tab("Diary", systemImage: "book") {
                    DiaryView()
                }
                Tab("Badges", systemImage: "trophy") {
                    BadgesView()
                }
                Tab("Profile", systemImage: "person.crop.circle") {
                    ProfileView()
                }
            }
            .environment(diary)
            .environment(map)
            .environment(badges)
            .task { await badges.load() }
            .task { UserLocation.shared.start() }
            .onChange(of: diary.revision) { Task { await badges.load() } }
            .overlay {
                if !badges.newlyEarned.isEmpty {
                    BadgeCelebration(badges: badges.newlyEarned) {
                        withAnimation { badges.newlyEarned = [] }
                    }
                    .transition(.opacity)
                }
            }
            .animation(.default, value: badges.newlyEarned.isEmpty)
        } else {
            ProgressView()
                .onAppear {
                    let diary = DiaryStore(session: session)
                    self.diary = diary
                    map = MapStore(session: session, diary: diary)
                    badges = BadgesStore(session: session)
                }
        }
    }
}
