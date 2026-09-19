import SwiftUI
import SwiftData

struct BadgesView: View {
    @Query private var sightings: [BirdSighting]

    private var progresses: [BadgeProgress] {
        BadgeProgress.compute(for: sightings)
    }

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 16)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(progresses, id: \.badge.id) { progress in
                        BadgeTile(progress: progress)
                    }
                }
                .padding()
            }
            .themedBackground()
            .toolbar {
                ToolbarItem(placement: .principal) {
                    FlowingTitle(text: "Badges")
                }
            }
        }
    }
}

private struct BadgeTile: View {
    let progress: BadgeProgress

    private var tierColor: Color {
        switch progress.badge.tier {
        case .bronze: Color(red: 0.8, green: 0.55, blue: 0.35)
        case .silver: Color(white: 0.75)
        case .gold: Color(red: 0.9, green: 0.75, blue: 0.35)
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: progress.badge.icon)
                .font(.system(size: 28))
                .foregroundStyle(progress.isEarned ? tierColor : Theme.textSecondary)

            Text(progress.badge.name)
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.textPrimary)

            Text(progress.badge.tier.label)
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary)

            if !progress.isEarned {
                Text("\(progress.progress)/\(progress.badge.criteriaValue)")
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Theme.backgroundElevated)
        .opacity(progress.isEarned ? 1 : 0.5)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    BadgesView()
        .modelContainer(for: BirdSighting.self, inMemory: true)
}
