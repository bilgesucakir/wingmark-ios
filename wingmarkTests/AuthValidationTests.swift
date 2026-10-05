import Testing
import UIKit
@testable import wingmark

@MainActor
struct AuthValidationTests {
    @Test(arguments: ["ada@example.com", "  ada@example.co.uk ", "a.b+c@d.io"])
    func validEmails(_ email: String) {
        #expect(AuthValidation.emailError(email) == nil)
    }

    @Test(arguments: ["", "ada", "ada@", "@example.com", "ada@example", "ada@.com", "a da@example.com", "a@b@c.com"])
    func invalidEmails(_ email: String) {
        #expect(AuthValidation.emailError(email) != nil)
    }

    @Test(arguments: ["birdsong2026", "123456789a", String(repeating: "a", count: 71) + "1"])
    func validPasswords(_ password: String) {
        #expect(AuthValidation.passwordError(password) == nil)
    }

    @Test(arguments: ["abcdefg1", "birdsg202", "abcdefghij", "1234567890", "şşşşşşşşş1", String(repeating: "a", count: 72) + "1"])
    func invalidPasswords(_ password: String) {
        #expect(AuthValidation.passwordError(password) != nil)
    }

    @Test func passwordMustNotContainEmailNameOrUsername() {
        #expect(AuthValidation.passwordError("Robin2026xyz", email: "robin@example.com") != nil)
        #expect(AuthValidation.passwordError("xxbirder99xx", username: "Birder99") != nil)
        // Parts shorter than 4 characters are allowed, matching the server.
        #expect(AuthValidation.passwordError("adalovelace1", email: "ada@example.com", username: "ada") == nil)
        let rules = PasswordRules(password: "robin2026xyz", email: "robin@example.com")
        #expect(rules.hasValidLength && rules.hasLetterAndDigit && !rules.avoidsPersonalInfo && !rules.isSatisfied)
    }

    @Test func usernameLength() {
        #expect(AuthValidation.usernameError("ab") != nil)
        #expect(AuthValidation.usernameError("ada") == nil)
        #expect(AuthValidation.usernameError(String(repeating: "a", count: 30)) == nil)
        #expect(AuthValidation.usernameError(String(repeating: "a", count: 31)) != nil)
    }

    @Test func codeMustBeSixASCIIDigits() {
        #expect(AuthValidation.isValidCode("123456"))
        #expect(!AuthValidation.isValidCode("12345"))
        #expect(!AuthValidation.isValidCode("12345a"))
        #expect(!AuthValidation.isValidCode("١٢٣٤٥٦"))
    }

    @Test func serverFieldErrorsUseAppText() {
        let error = APIError.server(
            status: 400,
            body: APIErrorBody(status: 400, code: .validationFailed, message: "server", path: nil,
                               validationErrors: ["email": "must be a well-formed email address"])
        )
        #expect(AuthValidation.serverFieldErrors(error) == ["email": AuthValidation.serverFieldMessage(for: "email")])
    }
}

@MainActor
struct PasswordRuleStateTests {
    @Test func rulesStayNeutralUntilTheUserTypes() {
        let empty = PasswordRules(password: "")
        #expect(empty.isUntouched)
        #expect([empty.hasValidLength, empty.hasLetterAndDigit, empty.avoidsPersonalInfo].map(empty.state(isMet:)) == [.neutral, .neutral, .neutral])
    }

    @Test func onceTypingStartsEachRuleIsMetOrUnmet() {
        let typing = PasswordRules(password: "abc", email: "robin@example.com")
        #expect(!typing.isUntouched)
        #expect(typing.state(isMet: typing.hasValidLength) == .unmet)
        #expect(typing.state(isMet: typing.hasLetterAndDigit) == .unmet)
        #expect(typing.state(isMet: typing.avoidsPersonalInfo) == .met)
        let good = PasswordRules(password: "birdsong2026")
        #expect([good.hasValidLength, good.hasLetterAndDigit, good.avoidsPersonalInfo].allSatisfy { good.state(isMet: $0) == .met })
    }

    // WCAG relative luminance and contrast ratio.
    private func luminance(_ color: UIColor, _ traits: UITraitCollection) -> Double {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.resolvedColor(with: traits).getRed(&r, green: &g, blue: &b, alpha: &a)
        func lin(_ c: CGFloat) -> Double { Double(c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)) }
        return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
    }

    private func contrast(_ color: UIColor, on background: UIColor, _ traits: UITraitCollection) -> Double {
        let a = luminance(color, traits), b = luminance(background, traits)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    @Test func theContrastHelperMatchesTheWCAGDefinition() {
        let traits = UITraitCollection(userInterfaceStyle: .light)
        #expect(abs(contrast(.black, on: .white, traits) - 21) < 0.01)
        #expect(abs(contrast(.white, on: .white, traits) - 1) < 0.01)
    }

    @Test(arguments: [
        UIUserInterfaceStyle.light, .dark
    ])
    func theUnmetRedMeetsTheTextContrastMinimum(style: UIUserInterfaceStyle) throws {
        for highContrast in [false, true] {
            let traits = UITraitCollection {
                $0.userInterfaceStyle = style
                $0.accessibilityContrast = highContrast ? .high : .normal
            }
            let red = try #require(UIColor(named: "UnmetRule", in: .main, compatibleWith: traits))
            // The two surfaces the checklist sits on: the grouped background and, in dark mode, a card.
            let mode = style == .dark ? "dark" : "light"
            for background in [UIColor.systemGroupedBackground, UIColor.secondarySystemGroupedBackground] {
                #expect(contrast(red, on: background, traits) >= 4.5,
                        "UnmetRule is too faint in \(mode) mode, high contrast \(highContrast)")
            }
        }
    }
}
