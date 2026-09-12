import SwiftUI
import SwiftData

struct ProfileView: View {
    @Query private var sightings: [BirdSighting]

    private var speciesCount: Int {
        Set(sightings.compactMap { $0.species?.commonName }).count
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(Theme.accent)

                HStack(spacing: 32) {
                    StatColumn(value: sightings.count, label: "sightings")
                    StatColumn(value: speciesCount, label: "species")
                }
                .padding(.top, 8)

                Spacer()
            }
            .padding(.top, 40)
            .frame(maxWidth: .infinity)
            .themedBackground()
            .toolbar {
                ToolbarItem(placement: .principal) {
                    FlowingTitle(text: "Profile")
                }
            }
        }
    }
}

private struct StatColumn: View {
    let value: Int
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.title2.bold())
                .foregroundStyle(Theme.textPrimary)
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
    }
}

#Preview {
    ProfileView()
        .modelContainer(for: BirdSighting.self, inMemory: true)
}
