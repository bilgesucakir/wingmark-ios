import SwiftUI

/// The tour inside the app, for an account that hasn't seen it yet. The server is the source of truth
/// (`walkthroughSeenAt`), so it follows the account to other devices and shows again if that flag is cleared. This device
/// only remembers a close that the server hasn't confirmed yet (for example while offline), so it doesn't show it twice.
struct AppWalkthrough {
    var defaults: UserDefaults = .standard

    private func key(_ userId: UUID) -> String { "walkthroughSyncPending.\(userId.uuidString.lowercased())" }

    /// Closed on this device, but the server hasn't been told yet.
    func isSyncPending(userId: UUID) -> Bool { defaults.bool(forKey: key(userId)) }

    func shouldShow(userId: UUID, seenOnServer: Bool) -> Bool {
        !seenOnServer && !isSyncPending(userId: userId)
    }

    func markClosed(userId: UUID) { defaults.set(true, forKey: key(userId)) }

    func markSynced(userId: UUID) { defaults.removeObject(forKey: key(userId)) }
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
                    OnboardingPageView(page: item, topInset: 44, bottomInset: 16).tag(index + 1)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Swiping and the dots move between pages; the button only appears at the end. Its space is always kept.
            Button(action: onFinish) {
                Text("Get Started").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .opacity(page == pages.count ? 1 : 0)
            .disabled(page != pages.count)
            .accessibilityHidden(page != pages.count)

            pageDots
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 12)
        .overlay(alignment: .topTrailing) {
            Button(action: onFinish) {
                Image(systemName: "xmark")
                    .font(.footnote.weight(.semibold))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel(Text("Close"))
            .padding(12)
        }
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, onFinish)
    }

    /// Drawn here rather than by the system so they sit at the bottom of the screen.
    private var pageDots: some View {
        HStack(spacing: 10) {
            ForEach(0...pages.count, id: \.self) { index in
                Circle()
                    .fill(index == page ? Color.primary : Color.secondary.opacity(0.4))
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.quaternary, in: .capsule)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Page \(page + 1) of \(pages.count + 1)"))
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
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                Text("Here is a quick look around. You can close this at any time.")
                    .font(.subheadline)
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
