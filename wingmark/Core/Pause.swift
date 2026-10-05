import Foundation

/// How a debounce waits. The app uses the real timer; tests replace it so they never wait on one.
nonisolated struct Pause: Sendable {
    var wait: @Sendable (Duration) async throws -> Void

    static let live = Pause { try await Task.sleep(for: $0) }
}
