import Testing
@testable import wingmark

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
