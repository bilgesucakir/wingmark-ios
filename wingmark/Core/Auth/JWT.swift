import Foundation

enum JWT {
    static func subject(of token: String) -> UUID? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var base64 = parts[1].replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64 += "=" }
        guard let data = Data(base64Encoded: base64),
              let claims = try? JSONDecoder().decode(Claims.self, from: data)
        else { return nil }
        return UUID(uuidString: claims.sub)
    }

    private struct Claims: Decodable {
        let sub: String
    }
}
