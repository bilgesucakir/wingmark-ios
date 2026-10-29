import Foundation

enum JSONCoding {
    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = parseDate(string) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unrecognized date: \(string)")
        }
        return decoder
    }

    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(date.formatted(.iso8601))
        }
        return encoder
    }

    nonisolated static func parseDate(_ string: String) -> Date? {
        if let date = try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(string) {
            return date
        }
        if let date = try? Date.ISO8601FormatStyle().parse(string) {
            return date
        }
        // Trim to milliseconds for precision the format style rejects.
        guard let dot = string.firstIndex(of: "."),
              let zoneStart = string[dot...].firstIndex(where: { $0 == "Z" || $0 == "+" || $0 == "-" })
        else { return nil }
        let fraction = string[string.index(after: dot)..<zoneStart].prefix(3)
        let trimmed = string[..<dot] + "." + fraction + string[zoneStart...]
        return try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(String(trimmed))
    }
}
