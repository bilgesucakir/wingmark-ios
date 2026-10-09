import SwiftUI

struct BadgesView: View {
    @Environment(BadgesStore.self) private var store
    @Environment(AuthSession.self) private var session
    @Environment(AppRouter.self) private var router
    @State private var selected: BadgeProgress?

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
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(store.badges) { badge in
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
            .navigationTitle("Badges")
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
            Text("\(store.earnedCount) of \(store.badges.count) earned")
                .font(.headline)
            ProgressView(value: Double(store.earnedCount), total: Double(max(store.badges.count, 1)))
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

    var body: some View {
        ZStack {
            Circle()
                .fill(earned ? AnyShapeStyle(tier.color.gradient) : AnyShapeStyle(Color(.systemGray5)))
            Circle()
                .strokeBorder(earned ? tier.color : Color(.systemGray3), lineWidth: 3)
            symbol
                .font(.system(size: size * 0.45))
                .grayscale(earned ? 0 : 1)
                .opacity(earned ? 1 : 0.45)
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

    /// The backend sends emoji; SF Symbol names (e.g. `trophy.fill`) are supported too.
    @ViewBuilder
    private var symbol: some View {
        let value = icon?.trimmingCharacters(in: .whitespaces) ?? ""
        if value.isEmpty {
            Image(systemName: "trophy.fill").foregroundStyle(.white)
        } else if value.allSatisfy({ $0.isASCII }), UIImage(systemName: value) != nil {
            Image(systemName: value).foregroundStyle(.white)
        } else {
            Text(value)
        }
    }
}

private struct BadgeCard: View {
    let badge: BadgeProgress
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        VStack(spacing: 12) {
            BadgeIcon(icon: badge.icon, tier: badge.tier, earned: badge.earned)
            Text(badge.name)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2, reservesSpace: true)
            Text(badge.tier.title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
            if badge.earned, let earnedAt = badge.earnedAt {
                Text(earnedAt, format: .dateTime.day().month().year())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 4) {
                    ProgressView(value: badge.fraction)
                        .tint(badge.tier.color)
                    Text("\(badge.progress) / \(badge.target)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
        .overlay {
            // The card fill is nearly the page color in light mode, so with Increase Contrast it needs an outline.
            if contrast == .increased {
                RoundedRectangle(cornerRadius: 16).strokeBorder(Color(.separator), lineWidth: 1.5)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(badge.earned
            ? Text("Earned")
            : Text("\(badge.progress) of \(badge.target)"))
    }
}

private struct BadgeDetailSheet: View {
    let badge: BadgeProgress

    var body: some View {
        VStack(spacing: 16) {
            BadgeIcon(icon: badge.icon, tier: badge.tier, earned: badge.earned, size: 96)
            VStack(spacing: 8) {
                Text(badge.name).font(.title2.bold())
                Text(badge.tier.title)
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
                    ProgressView(value: badge.fraction).tint(badge.tier.color)
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
        }
        .sensoryFeedback(.success, trigger: appeared)
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.55)) { appeared = true }
        }
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, onDismiss)
    }
}
