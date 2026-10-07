import Observation
import UIKit

/// Holds a link until the signed-in screens can act on it, so it survives launch, sign-in and consent screens.
@Observable
final class AppRouter {
    static let shared = AppRouter()

    var pending: AppLink?

    func open(_ link: AppLink) { pending = link }
}

enum QuickAction {
    static let logSightingType = "com.bilgesucakir.wingmark.log-sighting"

    /// Dynamic so the title follows the in-app language.
    static func install() {
        UIApplication.shared.shortcutItems = [
            UIApplicationShortcutItem(
                type: logSightingType,
                localizedTitle: String(localized: "Log a Sighting", bundle: .app),
                localizedSubtitle: nil,
                icon: UIApplicationShortcutIcon(systemImageName: "plus.circle")
            ),
        ]
    }

    @discardableResult
    static func handle(_ item: UIApplicationShortcutItem, router: AppRouter = .shared) -> Bool {
        guard item.type == logSightingType else { return false }
        router.open(.logSighting)
        return true
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication, configurationForConnecting session: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        if let item = options.shortcutItem { QuickAction.handle(item) }
        let configuration = UISceneConfiguration(name: nil, sessionRole: session.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}

final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem) async -> Bool {
        QuickAction.handle(shortcutItem)
    }
}
