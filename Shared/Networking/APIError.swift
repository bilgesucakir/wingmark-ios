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
    case termsNotAccepted = "TERMS_NOT_ACCEPTED"
    case privacyNotAccepted = "PRIVACY_NOT_ACCEPTED"
    case consentVersionMismatch = "CONSENT_VERSION_MISMATCH"
    case ageNotConfirmed = "AGE_NOT_CONFIRMED"
    case weakPassword = "WEAK_PASSWORD"
    case passwordBreached = "PASSWORD_BREACHED"
    case rateLimited = "RATE_LIMITED"
    case requestTooLarge = "REQUEST_TOO_LARGE"
    case photoQuotaExceeded = "PHOTO_QUOTA_EXCEEDED"
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
    /// From the `Retry-After` header on 429 responses, in seconds.
    var retryAfter: TimeInterval?
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

    var isRateLimited: Bool { status == 429 || code == .rateLimited }

    var retryAfter: TimeInterval? {
        if case .server(_, let body) = self { return body?.retryAfter }
        return nil
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
                return String(localized: "You're offline. Check your connection and try again.", bundle: .app)
            case .timedOut:
                return String(localized: "The server is taking too long to respond. Please try again.", bundle: .app)
            default:
                return String(localized: "Couldn't reach the server. Please try again.", bundle: .app)
            }
        case .decoding:
            return String(localized: "Something went wrong. Please try again.", bundle: .app)
        case .sessionExpired:
            return String(localized: "Your session has ended. Please log in again.", bundle: .app)
        case .server(let status, let body):
            if isRateLimited { return Self.rateLimitMessage(retryAfter: body?.retryAfter) }
            return Self.message(for: body?.code, status: status)
        }
    }

    static func rateLimitMessage(retryAfter: TimeInterval?) -> String {
        let minutes = Int(((retryAfter ?? 60) / 60).rounded(.up))
        return minutes <= 1
            ? String(localized: "Too many attempts. Try again in a minute.", bundle: .app)
            : String(localized: "Too many attempts. Try again in \(minutes) minutes.", bundle: .app)
    }

    private static func message(for code: APIErrorCode?, status: Int) -> String {
        switch code {
        case .validationFailed:
            String(localized: "Please check the highlighted fields.", bundle: .app)
        case .observedAtInFuture:
            String(localized: "The sighting date can't be in the future.", bundle: .app)
        case .samePassword:
            String(localized: "Your new password must be different from the current one.", bundle: .app)
        case .invalidProfilePicture:
            String(localized: "Couldn't save that profile picture.", bundle: .app)
        case .invalidOrExpiredCode:
            String(localized: "That code is wrong or has expired.", bundle: .app)
        case .invalidFile, .unsupportedMediaType:
            String(localized: "Couldn't read that photo.", bundle: .app)
        case .photoQuotaExceeded:
            String(localized: "You have reached the photo limit. Delete some photos first.", bundle: .app)
        case .fileTooLarge:
            String(localized: "That photo is too large.", bundle: .app)
        case .invalidCredentials:
            String(localized: "Wrong email or password.", bundle: .app)
        case .emailNotVerified:
            String(localized: "Please verify your email address first.", bundle: .app)
        case .wrongPassword:
            String(localized: "The password is incorrect.", bundle: .app)
        case .notFound:
            String(localized: "This item no longer exists.", bundle: .app)
        case .emailTaken:
            String(localized: "An account with this email already exists.", bundle: .app)
        case .usernameTaken:
            String(localized: "This username is already taken.", bundle: .app)
        case .invalidReference:
            String(localized: "That species is no longer available.", bundle: .app)
        case .externalServiceError:
            String(localized: "Bird sounds are unavailable right now.", bundle: .app)
        case .unauthenticated, .invalidOrExpiredToken:
            String(localized: "Your session has ended. Please log in again.", bundle: .app)
        case .lastAdmin, .conflict:
            String(localized: "This action conflicts with the current state. Please refresh and try again.", bundle: .app)
        case .internalError:
            String(localized: "The server ran into a problem. Please try again.", bundle: .app)
        case .weakPassword:
            String(localized: "Choose a less predictable password that doesn't include your email or username.", bundle: .app)
        case .passwordBreached:
            String(localized: "This password appeared in a data breach. Please choose another.", bundle: .app)
        case .rateLimited:
            rateLimitMessage(retryAfter: nil)
        case .ageNotConfirmed:
            String(localized: "Please confirm your age to create an account.", bundle: .app)
        case .termsNotAccepted, .privacyNotAccepted, .consentVersionMismatch:
            String(localized: "Our terms were just updated. Please review and accept them again.", bundle: .app)
        case .malformedRequest, .invalidParameter, .badRequest, .invalidBounds, .forbidden, .requestTooLarge,
             .cannotModifySelf, .methodNotAllowed, .unknown, nil:
            String(localized: "Something went wrong. Please try again.", bundle: .app)
        }
    }
}
