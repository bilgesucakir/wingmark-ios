import SwiftUI

struct MainTabView: View {
    @Environment(AuthSession.self) private var session
    @State private var diary: DiaryStore?
    @State private var map: MapStore?
    @State private var badges: BadgesStore?
    @SceneStorage("selectedTab") private var selectedTab = MainTab.map

    var body: some View {
        if let diary, let map, let badges {
            TabView(selection: $selectedTab) {
                Tab("Map", systemImage: "map", value: .map) {
                    SightingsMapView()
                }
                Tab("Guide", systemImage: "text.book.closed", value: .guide) {
                    GuideView()
                }
                Tab("Diary", systemImage: "book", value: .diary) {
                    DiaryView()
                }
                Tab("Badges", systemImage: "trophy", value: .badges) {
                    BadgesView()
                }
                Tab("Profile", systemImage: "person.crop.circle", value: .profile) {
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
            .fullScreenCover(isPresented: Binding(get: { !session.pendingConsents.isEmpty }, set: { _ in })) {
                ConsentUpdateView()
            }
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

enum MainTab: String {
    case map, guide, diary, badges, profile
}
