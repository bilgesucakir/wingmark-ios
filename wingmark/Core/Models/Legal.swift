import Foundation

enum ConsentType: String, Codable, Sendable, CaseIterable {
    case terms = "TERMS"
    case privacy = "PRIVACY"

    var title: String {
        switch self {
        case .terms: String(localized: "Terms of Service", bundle: .app)
        case .privacy: String(localized: "Privacy Policy", bundle: .app)
        }
    }

    /// Whole sentences, since Turkish inflects the document name.
    var acceptanceLabel: String {
        switch self {
        case .terms: String(localized: "I accept the Terms of Service", bundle: .app)
        case .privacy: String(localized: "I accept the Privacy Policy", bundle: .app)
        }
    }
}

/// A null version means that document isn't published yet, so nothing needs accepting.
struct LegalDocuments: Codable, Sendable, Equatable {
    var termsVersion: String?
    var termsUrl: String?
    var privacyVersion: String?
    var privacyUrl: String?

    static let unpublished = LegalDocuments()

    func version(of type: ConsentType) -> String? {
        switch type {
        case .terms: termsVersion
        case .privacy: privacyVersion
        }
    }

    func url(of type: ConsentType) -> URL? {
        let value = switch type {
        case .terms: termsUrl
        case .privacy: privacyUrl
        }
        return value.flatMap(URL.init(string:))
    }

    /// Documents with a published version, in display order.
    var published: [ConsentType] { ConsentType.allCases.filter { version(of: $0) != nil } }
}

struct Consent: Codable, Sendable, Equatable {
    let type: ConsentType
    let version: String
    let acceptedAt: Date
}

struct ConsentResult: Decodable, Sendable {
    let pendingConsents: [String]

    var pendingTypes: [ConsentType] { pendingConsents.compactMap(ConsentType.init(rawValue:)) }
}

enum LegalAPI {
    static func documents() -> Endpoint<LegalDocuments> {
        Endpoint(.get, "legal", requiresAuth: false)
    }

    static func consents(userId: UUID) -> Endpoint<[Consent]> {
        Endpoint(.get, "users/\(userId.uuidString.lowercased())/consents")
    }

    static func accept(_ type: ConsentType, version: String, userId: UUID) -> Endpoint<ConsentResult> {
        Endpoint(.post, "users/\(userId.uuidString.lowercased())/consents", json: ["type": type.rawValue, "version": version])
    }

    static func export(userId: UUID) -> Endpoint<RawResponse> {
        Endpoint(.get, "users/\(userId.uuidString.lowercased())/export")
    }
}
