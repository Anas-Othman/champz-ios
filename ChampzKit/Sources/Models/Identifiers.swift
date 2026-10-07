import Foundation

/// A typed opaque ID. `MatchID` and `VenueID` cannot be mixed up, and routes carry
/// IDs instead of whole models.
///
/// The backend's primary keys are ULIDs (26-character strings, `LUIDField`), so the raw
/// value is a `String`. Decodes strictly: a missing, null or empty ID fails the response.
/// A legacy integer is accepted and kept as its decimal text.
public struct Identifier<Tag>: Hashable, Sendable, Codable, CustomStringConvertible, ExpressibleByStringLiteral {
    public let raw: String

    public init(_ raw: String) {
        self.raw = raw
    }

    public init(stringLiteral value: String) {
        raw = value
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let text = try? container.decode(String.self) {
            guard !text.isEmpty else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "ID must not be empty")
            }
            raw = text
        } else if let int = try? container.decode(Int.self) {
            raw = String(int)
        } else {
            throw DecodingError.typeMismatch(
                String.self,
                .init(codingPath: decoder.codingPath, debugDescription: "ID must be a string")
            )
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(raw)
    }

    public var description: String {
        raw
    }
}

public enum MatchTag {}
public enum VenueTag {}
public enum CourtTag {}
public enum BookingTag {}
public enum TournamentTag {}
public enum TeamTag {}
public enum PlayerTag {}
public enum PaymentTag {}
public enum PaymentSessionTag {}
public enum JoinRequestTag {}
public enum NotificationTag {}
public enum PositionTag {}
public enum CountryTag {}
public enum CityTag {}

public typealias MatchID = Identifier<MatchTag>
public typealias VenueID = Identifier<VenueTag>
public typealias CourtID = Identifier<CourtTag>
public typealias BookingID = Identifier<BookingTag>
public typealias TournamentID = Identifier<TournamentTag>
public typealias TeamID = Identifier<TeamTag>
public typealias PlayerID = Identifier<PlayerTag>
public typealias PaymentID = Identifier<PaymentTag>
public typealias PaymentSessionID = Identifier<PaymentSessionTag>
public typealias JoinRequestID = Identifier<JoinRequestTag>
public typealias NotificationID = Identifier<NotificationTag>
public typealias PositionID = Identifier<PositionTag>
public typealias CountryID = Identifier<CountryTag>
public typealias CityID = Identifier<CityTag>
