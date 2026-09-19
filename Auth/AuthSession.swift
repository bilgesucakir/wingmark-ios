import Foundation

@Observable
final class AuthSession {
    private(set) var currentUser: AuthenticatedUser?
    private(set) var accessToken: String?
    private(set) var refreshToken: String?
    var isAuthenticated: Bool { currentUser != nil }

    var isBusy = false
    var errorMessage: String?

    private let service: AuthServicing

    init(service: AuthServicing = BackendAuthService()) {
        self.service = service
    }

    func login(email: String, password: String) async {
        errorMessage = nil
        isBusy = true
        defer { isBusy = false }
        do {
            apply(try await service.login(email: email, password: password))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func register(username: String, firstName: String, lastName: String, email: String, password: String) async {
        errorMessage = nil
        isBusy = true
        defer { isBusy = false }
        do {
            apply(try await service.register(username: username, firstName: firstName, lastName: lastName, email: email, password: password))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func logout() {
        currentUser = nil
        accessToken = nil
        refreshToken = nil
    }

    private func apply(_ result: AuthResult) {
        currentUser = result.user
        accessToken = result.accessToken
        refreshToken = result.refreshToken
    }
}
