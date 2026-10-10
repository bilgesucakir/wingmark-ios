import SwiftUI

struct MainTabView: View {
    @Environment(AuthSession.self) private var session
    @Environment(AppRouter.self) private var router
    @State private var diary: DiaryStore?
    @State private var map: MapStore?
    @State private var badges: BadgesStore?
    @SceneStorage("selectedTab") private var selectedTab = MainTab.map
    @State private var showsWalkthrough = false

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
            // The widgets are built from the diary, which otherwise loads only when the Diary tab is opened.
            .task { if !diary.hasLoaded { await diary.load() } }
            .task { UserLocation.shared.start() }
            .onChange(of: diary.revision) { Task { await badges.load() } }
            .onChange(of: diary.logs, initial: true) { syncWidgets(diary: diary, badges: badges) }
            .onChange(of: badges.badges) { syncWidgets(diary: diary, badges: badges) }
            .onChange(of: router.pending, initial: true) { route() }
            .onChange(of: session.pendingConsents) { route() }
            .overlay {
                if !badges.newlyEarned.isEmpty {
                    BadgeCelebration(badges: badges.newlyEarned) {
                        withAnimation { badges.newlyEarned = [] }
                    }
                    .transition(.opacity)
                }
            }
            .animation(.default, value: badges.newlyEarned.isEmpty)
            .task(id: session.profile?.id) { checkWalkthrough() }
            .onChange(of: session.pendingConsents) { checkWalkthrough() }
            .background {
                // Its own view, because one view can only present one cover.
                Color.clear.fullScreenCover(isPresented: $showsWalkthrough) {
                    WalkthroughView(name: session.profile?.displayName ?? "") { finishWalkthrough() }
                }
            }
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

    private func checkWalkthrough() {
        guard session.pendingConsents.isEmpty, let profile = session.profile else { return }
        if AppWalkthrough().shouldShow(userId: profile.id, createdAt: profile.createdAt) { showsWalkthrough = true }
    }

    private func finishWalkthrough() {
        if let id = session.profile?.id { AppWalkthrough().markSeen(userId: id) }
        showsWalkthrough = false
    }

    private func syncWidgets(diary: DiaryStore, badges: BadgesStore) {
        // A filtered diary only holds the matches, so the widgets would show the wrong latest sighting.
        guard !diary.filter.isActive, diary.hasLoaded else { return }
        Task {
            await WidgetSync.update(logs: diary.logs, badges: badges.badges, language: AppLanguage.current.code) {
                if case .signedIn = session.state { true } else { false }
            }
        }
    }

    /// Waits while a consent screen is up; the Diary tab picks up what it needs once it is shown.
    private func route() {
        guard let link = router.pending, session.pendingConsents.isEmpty else { return }
        switch link {
        case .badges:
            selectedTab = .badges
            router.pending = nil
        case .guide:
            selectedTab = .guide
            router.pending = nil
        case .badge:
            selectedTab = .badges
        case .species:
            selectedTab = .guide
        case .logSighting, .sighting:
            selectedTab = .diary
        }
    }
}

enum MainTab: String {
    case map, guide, diary, badges, profile
}
