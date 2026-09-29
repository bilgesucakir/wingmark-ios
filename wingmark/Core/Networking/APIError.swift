import Foundation

enum APIErrorCode: String, Decodable, Sendable {
    case validationFailed = "VALIDATION_FAILED"
    case malformedRequest = "MALFORMED_REQUEST"
    case invalidParameter = "INVALID_PARAMETER"
    case badRequest = "BAD_REQUEST"
    case observedAtInFuture = "OBSERVED_AT_IN_FUTURE"
    case samePassword = "SAME_PASSWORD"
    case invalidProfilePicture = "INVALID_PROFILE_PICTURE"
    case invalidBounds = "INVALID_BOUNDS"
    case invalidOrExpiredCode = "INVALID_OR_EXPIRED_CODE"
    case invalidFile = "INVALID_FILE"
    case unauthenticated = "UNAUTHENTICATED"
    case invalidCredentials = "INVALID_CREDENTIALS"
    case invalidOrExpiredToken = "INVALID_OR_EXPIRED_TOKEN"
    case emailNotVerified = "EMAIL_NOT_VERIFIED"
    case wrongPassword = "WRONG_PASSWORD"
    case forbidden = "FORBIDDEN"
    case cannotModifySelf = "CANNOT_MODIFY_SELF"
    case notFound = "NOT_FOUND"
    case methodNotAllowed = "METHOD_NOT_ALLOWED"
    case emailTaken = "EMAIL_TAKEN"
    case usernameTaken = "USERNAME_TAKEN"
    case lastAdmin = "LAST_ADMIN"
    case conflict = "CONFLICT"
    case fileTooLarge = "FILE_TOO_LARGE"
    case unsupportedMediaType = "UNSUPPORTED_MEDIA_TYPE"
    case invalidReference = "INVALID_REFERENCE"
    case internalError = "INTERNAL_ERROR"
    case externalServiceError = "EXTERNAL_SERVICE_ERROR"
    case unknown

    nonisolated init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = APIErrorCode(rawValue: raw) ?? .unknown
    }
}

struct APIErrorBody: Decodable, Sendable, Equatable {
    let status: Int?
    let code: APIErrorCode?
    let message: String?
    let path: String?
    let validationErrors: [String: String]?
}

enum APIError: Error, Sendable {
    case server(status: Int, body: APIErrorBody?)
    case network(URLError)
    case decoding(String)
    case sessionExpired

    var code: APIErrorCode? {
        if case .server(_, let body) = self { return body?.code }
        return nil
    }

    var status: Int? {
        if case .server(let status, _) = self { return status }
        return nil
    }

    var validationErrors: [String: String] {
        if case .server(_, let body) = self { return body?.validationErrors ?? [:] }
        return [:]
    }

    var isAuthRejection: Bool {
        guard let status else { return false }
        return status == 401 || status == 403
    }

    var isCancellation: Bool {
        if case .network(let error) = self { return error.code == .cancelled }
        return false
    }

    var userMessage: String {
        switch self {
        case .network(let error):
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
                return String(localized: "You're offline. Check your connection and try again.")
            case .timedOut:
                return String(localized: "The server is taking too long to respond. Please try again.")
            default:
                return String(localized: "Couldn't reach the server. Please try again.")
            }
        case .decoding:
            return String(localized: "Something went wrong. Please try again.")
        case .sessionExpired:
            return String(localized: "Your session has ended. Please log in again.")
        case .server(let status, let body):
            return Self.message(for: body?.code, status: status)
        }
    }

    private static func message(for code: APIErrorCode?, status: Int) -> String {
        switch code {
        case .validationFailed:
            String(localized: "Please check the highlighted fields.")
        case .observedAtInFuture:
            String(localized: "The sighting date can't be in the future.")
        case .samePassword:
            String(localized: "Your new password must be different from the current one.")
        case .invalidProfilePicture:
            String(localized: "Couldn't save that profile picture.")
        case .invalidOrExpiredCode:
            String(localized: "That code is wrong or has expired.")
        case .invalidFile, .unsupportedMediaType:
            String(localized: "Couldn't read that photo.")
        case .fileTooLarge:
            String(localized: "That photo is too large.")
        case .invalidCredentials:
            String(localized: "Wrong email or password.")
        case .emailNotVerified:
            String(localized: "Please verify your email address first.")
        case .wrongPassword:
            String(localized: "The password is incorrect.")
        case .notFound:
            String(localized: "This item no longer exists.")
        case .emailTaken:
            String(localized: "An account with this email already exists.")
        case .usernameTaken:
            String(localized: "This username is already taken.")
        case .invalidReference:
            String(localized: "That species is no longer available.")
        case .externalServiceError:
            String(localized: "Bird sounds are unavailable right now.")
        case .unauthenticated, .invalidOrExpiredToken:
            String(localized: "Your session has ended. Please log in again.")
        case .lastAdmin, .conflict:
            String(localized: "This action conflicts with the current state. Please refresh and try again.")
        case .internalError:
            String(localized: "The server ran into a problem. Please try again.")
        case .malformedRequest, .invalidParameter, .badRequest, .invalidBounds, .forbidden,
             .cannotModifySelf, .methodNotAllowed, .unknown, nil:
            String(localized: "Something went wrong. Please try again.")
        }
    }
}
