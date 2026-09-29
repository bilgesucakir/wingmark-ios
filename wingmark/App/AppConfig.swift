import Foundation

enum AppConfig {
    static let renderBaseURL = URL(string: "https://wingmark-backend.onrender.com")!

    /// Override with the `WINGMARK_BASE_URL` environment variable, e.g. `http://localhost:8080`.
    static let baseURL: URL = {
        if let override = ProcessInfo.processInfo.environment["WINGMARK_BASE_URL"],
           let url = URL(string: override), url.scheme != nil {
            return url
        }
        if let value = Bundle.main.object(forInfoDictionaryKey: "WingmarkAPIBaseURL") as? String,
           let url = URL(string: value), url.scheme != nil {
            return url
        }
        return renderBaseURL
    }()

    static let requestTimeout: TimeInterval = 30
}
