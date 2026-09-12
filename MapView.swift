import SwiftUI

struct MapView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                Image(systemName: "map")
                    .font(.system(size: 48))
                    .foregroundStyle(Theme.textSecondary)
                Text("Your sightings, mapped")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.top, 8)
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .themedBackground()
            .toolbar {
                ToolbarItem(placement: .principal) {
                    FlowingTitle(text: "Map")
                }
            }
        }
    }
}

#Preview {
    MapView()
}
