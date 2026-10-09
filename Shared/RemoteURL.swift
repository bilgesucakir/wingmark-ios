import Foundation

/// Builds URLs for photos that may be hosted elsewhere. Some paths mix accented letters with already-encoded
/// characters ("Tennōji…%2C"), and `URL(string:)` would then encode the `%` a second time and request a file that doesn't exist.
nonisolated enum RemoteURL {
    static func make(_ string: String, relativeTo base: URL? = nil) -> URL? {
        let ascii = string.unicodeScalars.map { scalar in
            scalar.isASCII ? String(scalar) : String(scalar).addingPercentEncoding(withAllowedCharacters: CharacterSet()) ?? ""
        }.joined()
        if let url = URL(string: ascii), url.scheme != nil { return url }
        return URL(string: ascii, relativeTo: base)?.absoluteURL
    }
}
