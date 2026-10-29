import Foundation

/// When to show Apple's own rating prompt: only right after a new sighting was saved, once per milestone, and never in the first session.
nonisolated enum ReviewPrompt {
    static let milestones = [10]

    private static let launchesKey = "reviewPromptLaunches"
    private static let askedKey = "reviewPromptLastMilestone"

    static func recordLaunch(defaults: UserDefaults = .standard) {
        defaults.set(defaults.integer(forKey: launchesKey) + 1, forKey: launchesKey)
    }

    /// Returns true at most once per milestone and remembers that it did. Call it after a successful save of a new sighting.
    static func shouldAsk(totalSightings: Int, isNewSighting: Bool, defaults: UserDefaults = .standard) -> Bool {
        guard isNewSighting, defaults.integer(forKey: launchesKey) >= 2 else { return false }
        let lastAsked = defaults.integer(forKey: askedKey)
        guard let reached = milestones.last(where: { $0 <= totalSightings }), reached > lastAsked else { return false }
        defaults.set(reached, forKey: askedKey)
        return true
    }
}
