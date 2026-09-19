import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(AuthSession.self) private var session
    @Query private var sightings: [BirdSighting]

    private var speciesCount: Int {
        Set(sightings.compactMap { $0.species?.commonName }).count
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(Theme.accent)

                if let user = session.currentUser {
                    VStack(spacing: 2) {
                        Text(user.fullName.trimmingCharacters(in: .whitespaces).isEmpty ? user.username : user.fullName)
                            .font(.headline)
                            .foregroundStyle(Theme.textPrimary)
                        Text("@\(user.username)")
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                        Text(user.email)
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                        Text("Joined \(user.createdAt, format: .dateTime.month(.wide).year())")
                            .font(.caption2)
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.top, 2)
                    }
                }

                HStack(spacing: 32) {
                    StatColumn(value: sightings.count, label: "sightings")
                    StatColumn(value: speciesCount, label: "species")
                }
                .padding(.top, 8)

                Button("Log Out", role: .destructive) {
                    session.logout()
                }
                .padding(.top, 8)

                Spacer()
            }
            .padding(.top, 32)
            .frame(maxWidth: .infinity)
            .themedBackground()
            .toolbar {
                ToolbarItem(placement: .principal) {
                    FlowingTitle(text: "Profile")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
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
        .environment(AuthSession())
}
