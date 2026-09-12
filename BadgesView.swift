import SwiftUI
import SwiftData

struct BadgesView: View {
    @Query private var sightings: [BirdSighting]

    private var speciesCount: Int {
        Set(sightings.compactMap { $0.species?.commonName }).count
    }

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 16)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    BadgeTile(icon: "trophy.fill", title: "First Sighting", earned: !sightings.isEmpty)
                    BadgeTile(icon: "trophy.fill", title: "10 Sightings", earned: sightings.count >= 10)
                    BadgeTile(icon: "trophy.fill", title: "5 Species", earned: speciesCount >= 5)
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
    let icon: String
    let title: String
    let earned: Bool

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(earned ? Theme.accent : Theme.textSecondary)
            Text(title)
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Theme.backgroundElevated)
        .opacity(earned ? 1 : 0.4)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    BadgesView()
        .modelContainer(for: BirdSighting.self, inMemory: true)
}
