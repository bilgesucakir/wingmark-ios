import SwiftUI

enum BadgeFilter: String, CaseIterable, Identifiable {
    case all, earned, notEarned

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: String(localized: "All", bundle: .app)
        case .earned: String(localized: "Unlocked", bundle: .app)
        case .notEarned: String(localized: "Locked", bundle: .app)
        }
    }

    func matches(_ badge: BadgeProgress) -> Bool {
        switch self {
        case .all: true
        case .earned: badge.earned
        case .notEarned: !badge.earned
        }
    }
}

struct BadgesView: View {
    @Environment(BadgesStore.self) private var store
    @Environment(AuthSession.self) private var session
    @Environment(AppRouter.self) private var router
    @State private var selected: BadgeProgress?
    @State private var filter = BadgeFilter.all

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                if store.badges.isEmpty {
                    emptyState
                        .containerRelativeFrame(.vertical)
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        summary
                        if shownBadges.isEmpty {
                            ContentUnavailableView(
                                filter == .earned ? "No unlocked badges yet" : "No badges to show",
                                systemImage: "trophy"
                            )
                            .padding(.top, 32)
                        }
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(shownBadges) { badge in
                                Button {
                                    selected = badge
                                } label: {
                                    BadgeCard(badge: badge)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(16)
                }
            }
            // Same page and card colors as the species detail list: white cards on a light grey page, dark grey on black.
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Badges")
            .toolbar {
                if !store.badges.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Picker("Filter", selection: $filter) {
                                ForEach(BadgeFilter.allCases) { Text($0.title).tag($0) }
                            }
                        } label: {
                            Label("Filter", systemImage: filter == .all
                                  ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                        }
                    }
                }
            }
            .refreshable { await store.load() }
            .task { if !store.hasLoaded { await store.load() } }
            .onChange(of: router.pending, initial: true) { openPendingBadge() }
            .onChange(of: store.badges) { openPendingBadge() }
            .sheet(item: $selected) { badge in
                BadgeDetailSheet(badge: badge)
                    .presentationDetents([.medium])
            }
        }
    }

    private var shownBadges: [BadgeProgress] { store.badges.filter(filter.matches) }

    /// Opens the badge a widget pointed at; if the list hasn't loaded yet, it waits for it.
    private func openPendingBadge() {
        guard session.pendingConsents.isEmpty, case .badge(let id)? = router.pending else { return }
        if let badge = store.badges.first(where: { $0.id == id }) {
            selected = badge
            router.pending = nil
        } else if store.hasLoaded, !store.isLoading {
            router.pending = nil
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(store.earnedCount) of \(store.totalCount) earned")
                .font(.headline)
            ProgressView(value: Double(store.earnedCount), total: Double(max(store.totalCount, 1)))
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if let error = store.loadError {
            ContentUnavailableView {
                Label("Couldn't load badges", systemImage: "wifi.exclamationmark")
            } description: {
                Text(error.userMessage)
            } actions: {
                Button("Try Again") { Task { await store.load() } }
            }
        } else if store.isLoading || !store.hasLoaded {
            ProgressView()
        } else {
            ContentUnavailableView("No badges yet", systemImage: "trophy")
        }
    }
}

struct BadgeIcon: View {
    let icon: String?
    let tier: BadgeTier
    let earned: Bool
    var size: CGFloat = 64
    /// A locked secret badge: a question mark in a grey circle, ringed in its tier color as the only hint.
    var isMystery = false

    var body: some View {
        ZStack {
            Circle()
                .fill(earned ? AnyShapeStyle(tier.color.gradient) : AnyShapeStyle(Color(.systemGray5)))
            Circle()
                .strokeBorder(earned || isMystery ? tier.edgeColor : Color(.systemGray3), lineWidth: 3)
            if isMystery {
                Image(systemName: "questionmark")
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundStyle(.secondary)
            } else {
                symbol
                    .font(.system(size: size * 0.45))
                    .grayscale(earned ? 0 : 1)
                    .opacity(earned ? 1 : 0.45)
            }
            if !earned {
                Image(systemName: "lock.fill")
                    .font(.system(size: size * 0.2, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(size * 0.08)
                    .background(Circle().fill(Color(.systemBackground)))
                    .offset(x: size * 0.32, y: size * 0.32)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    /// The tier colors are light, so an earned badge's symbol is dark; a locked one stays pale on its grey circle.
    private var symbolColor: Color { earned ? Color.black.opacity(0.75) : .white }

    /// The backend sends emoji; SF Symbol names (e.g. `trophy.fill`) are supported too.
    @ViewBuilder
    private var symbol: some View {
        let value = icon?.trimmingCharacters(in: .whitespaces) ?? ""
        if value.isEmpty {
            Image(systemName: "trophy.fill").foregroundStyle(symbolColor)
        } else if value.allSatisfy({ $0.isASCII }), UIImage(systemName: value) != nil {
            Image(systemName: value).foregroundStyle(symbolColor)
        } else {
            Text(value)
        }
    }
}

/// The tier name, with its own symbol for the top tier so it doesn't depend on color alone.
private struct TierLabel: View {
    let tier: BadgeTier

    var body: some View {
        if let symbol = tier.symbol {
            Label(tier.title, systemImage: symbol)
        } else {
            Text(tier.title)
        }
    }
}

private struct BadgeCard: View {
    let badge: BadgeProgress

    var body: some View {
        if badge.isLockedSecret { secretCard } else { regularCard }
    }

    private var secretCard: some View {
        VStack(spacing: 12) {
            BadgeIcon(icon: nil, tier: badge.tier, earned: false, isMystery: true)
            Text("Secret badge")
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2, reservesSpace: true)
            TierLabel(tier: badge.tier)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
            Text("Keep birding to unlock")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Secret badge, not yet unlocked"))
    }

    private var regularCard: some View {
        VStack(spacing: 12) {
            BadgeIcon(icon: badge.icon, tier: badge.tier, earned: badge.earned)
            Text(badge.name)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2, reservesSpace: true)
            TierLabel(tier: badge.tier)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
            if badge.earned, let earnedAt = badge.earnedAt {
                Text(earnedAt, format: .dateTime.day().month().year())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 4) {
                    ProgressView(value: badge.fraction)
                        .tint(badge.tier.edgeColor)
                    Text("\(badge.progress) / \(badge.target)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityValue(badge.earned
            ? Text("Earned")
            : Text("\(badge.progress) of \(badge.target)"))
    }
}

private struct BadgeDetailSheet: View {
    let badge: BadgeProgress

    var body: some View {
        if badge.isLockedSecret { secretSheet } else { regularSheet }
    }

    private var secretSheet: some View {
        VStack(spacing: 16) {
            BadgeIcon(icon: nil, tier: badge.tier, earned: false, size: 96, isMystery: true)
            VStack(spacing: 8) {
                Text("Secret badge").font(.title2.bold())
                TierLabel(tier: badge.tier)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("Keep birding to find out how to unlock this badge.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Secret badge, not yet unlocked"))
    }

    private var regularSheet: some View {
        VStack(spacing: 16) {
            BadgeIcon(icon: badge.icon, tier: badge.tier, earned: badge.earned, size: 96)
            VStack(spacing: 8) {
                Text(badge.name).font(.title2.bold())
                TierLabel(tier: badge.tier)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                if let description = badge.description {
                    Text(description)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
            }
            if badge.earned {
                if let earnedAt = badge.earnedAt {
                    Label {
                        Text("Earned on \(earnedAt.formatted(Date.FormatStyle(date: .long, time: .omitted).locale(.app)))")
                    } icon: {
                        Image(systemName: "checkmark.seal.fill")
                    }
                    .foregroundStyle(.green)
                }
            } else {
                VStack(spacing: 8) {
                    ProgressView(value: badge.fraction).tint(badge.tier.edgeColor)
                    Text("\(badge.progress) / \(badge.target)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 32)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Shown over the app when a save earns new badges.
struct BadgeCelebration: View {
    let badges: [BadgeProgress]
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)
            VStack(spacing: 16) {
                Text(badges.count == 1 ? "New badge!" : "New badges!")
                    .font(.title.bold())
                HStack(spacing: 16) {
                    ForEach(badges) { badge in
                        VStack(spacing: 8) {
                            BadgeIcon(icon: badge.icon, tier: badge.tier, earned: true, size: 88)
                                .scaleEffect(appeared || reduceMotion ? 1 : 0.3)
                                .rotationEffect(.degrees(appeared || reduceMotion ? 0 : -25))
                            Text(badge.name)
                                .font(.headline)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .padding(.top, 48)
            .background(.regularMaterial, in: .rect(cornerRadius: 28))
            .overlay(alignment: .topTrailing) {
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Close"))
                .padding(8)
            }
            .padding(32)
            if !reduceMotion { ConfettiView() }
        }
        .sensoryFeedback(.success, trigger: appeared)
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.55)) { appeared = true }
        }
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, onDismiss)
    }
}
