import Foundation

public extension JSONDecoder {
    /// The one decoder for API responses: snake_case keys, ISO-8601 dates with or
    /// without fractional seconds, and plain `yyyy-MM-dd` dates.
    static func api() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            if let date = Date.parseAPI(text) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "unrecognised date '\(text)'")
        }
        return decoder
    }
}

public extension JSONEncoder {
    static func api() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

public extension Date {
    /// Accepts "2026-10-02T18:30:00.123Z", "2026-10-02T18:30:00Z", "2026-10-02T18:30:00+03:00" and "2026-10-02".
    static func parseAPI(_ text: String, assumeLocal: Bool = false) -> Date? {
        // Venue wall-clock times arrive without a zone ("2026-10-10T20:00:00"); read them in the device zone.
        if assumeLocal, !text.hasSuffix("Z"), !text.contains("+") {
            if let date = try? Date(
                text,
                strategy: Date.ISO8601FormatStyle(timeZone: .current).year().month().day()
                    .time(includingFractionalSeconds: false)
            ) {
                return date
            }
        }
        if let date = try? Date(text, strategy: .iso8601.year().month().day().time(includingFractionalSeconds: true)) {
            return date
        }
        if let date = try? Date(text, strategy: .iso8601) {
            return date
        }
        if let date = try? Date(text, strategy: .iso8601.year().month().day().dateSeparator(.dash)) {
            return date
        }
        return nil
    }
}

public extension Locale {
    /// For parsing numbers the server writes with a dot decimal separator, whatever the user's locale.
    static let posix = Locale(identifier: "en_US_POSIX")
}
