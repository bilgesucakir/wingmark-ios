import SwiftUI

/// The tour inside the app, for an account that was just created. It is remembered per account on this device, and it
/// only applies to recent accounts so that someone who reinstalls an old account isn't walked through it again.
struct AppWalkthrough {
    static let newAccountDays = 7

    var defaults: UserDefaults = .standard

    private func key(_ userId: UUID) -> String { "hasSeenAppWalkthrough.\(userId.uuidString.lowercased())" }

    func shouldShow(userId: UUID, createdAt: Date?, now: Date = .now) -> Bool {
        guard let createdAt, now.timeIntervalSince(createdAt) < Double(Self.newAccountDays) * 86_400 else { return false }
        return !defaults.bool(forKey: key(userId))
    }

    func markSeen(userId: UUID) { defaults.set(true, forKey: key(userId)) }
}

struct WalkthroughView: View {
    let name: String
    let onFinish: () -> Void

    @State private var page = 0
    private let pages = OnboardingPage.allCases

    var body: some View {
        VStack(spacing: 16) {
            TabView(selection: $page) {
                welcomePage.tag(0)
                ForEach(Array(pages.enumerated()), id: \.element) { index, item in
                    OnboardingPageView(page: item).tag(index + 1)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button {
                if page < pages.count { withAnimation { page += 1 } } else { onFinish() }
            } label: {
                Text(page < pages.count ? "Next" : "Get Started").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(24)
        .overlay(alignment: .topTrailing) {
            Button(action: onFinish) {
                Image(systemName: "xmark")
                    .font(.headline)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel(Text("Close"))
            .padding(16)
        }
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, onFinish)
    }

    private var welcomePage: some View {
        ScrollView {
            VStack(spacing: 12) {
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 96)
                    .accessibilityHidden(true)
                Text("Welcome, \(name)")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                Text("Here is a quick look around. You can close this at any time.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.bottom, 48)
            .containerRelativeFrame(.vertical, alignment: .center)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}
