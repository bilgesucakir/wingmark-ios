import Foundation

enum AuthValidation {
    static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func emailError(_ value: String) -> String? {
        let email = trimmed(value)
        let parts = email.split(separator: "@", omittingEmptySubsequences: false)
        let valid = parts.count == 2 && !parts[0].isEmpty && parts[1].contains(".")
            && !parts[1].hasPrefix(".") && !parts[1].hasSuffix(".") && !email.contains(" ")
        return valid ? nil : String(localized: "Enter a valid email address.", bundle: .app)
    }

    /// Mirrors the backend: 8–72 characters with at least one ASCII letter and one digit.
    static func passwordError(_ value: String) -> String? {
        let hasLetter = value.unicodeScalars.contains { ("a"..."z").contains($0) || ("A"..."Z").contains($0) }
        let hasDigit = value.unicodeScalars.contains { ("0"..."9").contains($0) }
        let valid = (8...72).contains(value.count) && hasLetter && hasDigit
        return valid ? nil : String(localized: "Use 8–72 characters with at least one letter and one number.", bundle: .app)
    }

    static func usernameError(_ value: String) -> String? {
        (3...30).contains(trimmed(value).count) ? nil : String(localized: "Use 3–30 characters.", bundle: .app)
    }

    static func confirmationError(_ password: String, _ confirmation: String) -> String? {
        password == confirmation ? nil : String(localized: "Passwords don't match.", bundle: .app)
    }

    static func isValidCode(_ value: String) -> Bool {
        value.count == 6 && value.allSatisfy(\.isASCII) && value.allSatisfy(\.isNumber)
    }

    /// The app's own text for a server `validationErrors` field, never the server message.
    static func serverFieldMessage(for field: String) -> String {
        switch field {
        case "email": String(localized: "Enter a valid email address.", bundle: .app)
        case "password", "newPassword": String(localized: "Use 8–72 characters with at least one letter and one number.", bundle: .app)
        case "username": String(localized: "Use 3–30 characters.", bundle: .app)
        case "code": String(localized: "Enter the 6-digit code.", bundle: .app)
        default: String(localized: "Check this field.", bundle: .app)
        }
    }

    static func serverFieldErrors(_ error: APIError) -> [String: String] {
        Dictionary(uniqueKeysWithValues: error.validationErrors.keys.map { ($0, serverFieldMessage(for: $0)) })
    }
}
