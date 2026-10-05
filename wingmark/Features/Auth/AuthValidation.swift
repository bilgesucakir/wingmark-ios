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

    /// The checks the server repeats; it also rejects common and breached passwords, which only it can know.
    static func passwordError(_ value: String, email: String = "", username: String = "") -> String? {
        let rules = PasswordRules(password: value, email: email, username: username)
        if !rules.hasValidLength || !rules.hasLetterAndDigit {
            return String(localized: "Use 10–72 characters with at least one letter and one number.", bundle: .app)
        }
        if !rules.avoidsPersonalInfo {
            return String(localized: "Don't include your email or username in your password.", bundle: .app)
        }
        return nil
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
        case "password", "newPassword": String(localized: "Use 10–72 characters with at least one letter and one number.", bundle: .app)
        case "username": String(localized: "Use 3–30 characters.", bundle: .app)
        case "code": String(localized: "Enter the 6-digit code.", bundle: .app)
        default: String(localized: "Check this field.", bundle: .app)
        }
    }

    static func serverFieldErrors(_ error: APIError) -> [String: String] {
        Dictionary(uniqueKeysWithValues: error.validationErrors.keys.map { ($0, serverFieldMessage(for: $0)) })
    }
}

/// Mirrors the backend's password rules for live feedback.
struct PasswordRules {
    let password: String
    var email = ""
    var username = ""

    var hasValidLength: Bool { (10...72).contains(password.count) }

    var hasLetterAndDigit: Bool {
        let scalars = password.unicodeScalars
        return scalars.contains { ("a"..."z").contains($0) || ("A"..."Z").contains($0) }
            && scalars.contains { ("0"..."9").contains($0) }
    }

    /// The server rejects passwords containing the email's name part or the username when either has 4+ characters.
    var avoidsPersonalInfo: Bool {
        let local = AuthValidation.trimmed(email).split(separator: "@").first.map(String.init) ?? ""
        let personal = [local, AuthValidation.trimmed(username)].map { $0.lowercased() }.filter { $0.count >= 4 }
        let lowered = password.lowercased()
        return !personal.contains { lowered.contains($0) }
    }

    var isSatisfied: Bool { hasValidLength && hasLetterAndDigit && avoidsPersonalInfo }

    /// Nothing typed yet: the rules are just listed, not marked as failing.
    var isUntouched: Bool { password.isEmpty }

    func state(isMet: Bool) -> PasswordRuleState {
        isUntouched ? .neutral : (isMet ? .met : .unmet)
    }
}

enum PasswordRuleState: Equatable {
    case neutral, met, unmet
}
