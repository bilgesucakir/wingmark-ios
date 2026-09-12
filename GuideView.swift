import SwiftUI
import SwiftData

struct GuideView: View {
    @Query(sort: \Species.commonName) private var species: [Species]

    var body: some View {
        NavigationStack {
            Group {
                if species.isEmpty {
                    VStack {
                        Spacer()
                        Image(systemName: "book")
                            .font(.system(size: 48))
                            .foregroundStyle(Theme.textSecondary)
                        Text("No species identified yet")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.top, 8)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    List(species) { s in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(s.commonName)
                                .font(.headline)
                                .foregroundStyle(Theme.textPrimary)
                            Text(s.scientificName)
                                .font(.caption)
                                .italic()
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .listRowBackground(Theme.backgroundElevated)
                    }
                }
            }
            .themedBackground()
            .toolbar {
                ToolbarItem(placement: .principal) {
                    FlowingTitle(text: "Guide")
                }
            }
        }
    }
}

#Preview {
    GuideView()
        .modelContainer(for: Species.self, inMemory: true)
}
