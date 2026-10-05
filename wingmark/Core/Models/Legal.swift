import Foundation

enum ConsentType: String, Codable, Sendable, CaseIterable {
    case terms = "TERMS"
    case privacy = "PRIVACY"
    case age = "AGE"

    var title: String {
        switch self {
        case .terms: String(localized: "Terms of Service", bundle: .app)
        case .privacy: String(localized: "Privacy Policy", bundle: .app)
        case .age: String(localized: "Minimum age", bundle: .app)
        }
    }
}

extension [ConsentType] {
    /// Existing users only need to confirm their age, so the screen shouldn't talk about changed terms.
    var isAgeOnly: Bool { !isEmpty && allSatisfy { $0 == .age } }
}

/// A null version means that document isn't published yet, so nothing needs accepting.
struct LegalDocuments: Codable, Sendable, Equatable {
    var termsVersion: String?
    var termsUrl: String?
    var privacyVersion: String?
    var privacyUrl: String?
    /// The age people must confirm; null on a server that doesn't ask for it.
    var minimumAge: Int?

    static let unpublished = LegalDocuments()

    /// For age the "version" is the minimum age as text, which is what the server records and compares.
    func version(of type: ConsentType) -> String? {
        switch type {
        case .terms: termsVersion
        case .privacy: privacyVersion
        case .age: minimumAge.map(String.init)
        }
    }

    func url(of type: ConsentType) -> URL? {
        let value = switch type {
        case .terms: termsUrl
        case .privacy: privacyUrl
        case .age: String?.none
        }
        return value.flatMap(URL.init(string:))
    }

    /// Whole sentences, since Turkish inflects the document name.
    func acceptanceLabel(of type: ConsentType) -> String {
        switch type {
        case .terms: String(localized: "I accept the Terms of Service", bundle: .app)
        case .privacy: String(localized: "I accept the Privacy Policy", bundle: .app)
        case .age: String(localized: "I am \(minimumAge ?? 13) or older", bundle: .app)
        }
    }

    /// Items with a published version, in display order.
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
