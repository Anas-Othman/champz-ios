import Foundation

/// A tournament, as `GET /home/` (`tournaments`), `GET /tournaments/` and `GET /tournaments/{id}/`
/// describe it. One struct for card, list and detail: list items simply lack the detail-only fields.
public struct Tournament: Decodable, Hashable, Sendable, Identifiable {
    public let id: TournamentID
    @DefaultEmpty public var name: String
    @DefaultEmpty public var image: String
    @DefaultUnknown public var format: TournamentFormat
    /// Entry type: players register individually or as a team.
    @DefaultUnknown public var type: TournamentEntry
    public var ground: TournamentGround?

    /// `yyyy-MM-dd` and `HH:mm:ss`, venue local time.
    @DefaultEmpty public var startDate: String
    @DefaultEmpty public var endDate: String
    @DefaultEmpty public var startTime: String
    @DefaultEmpty public var endTime: String

    /// Price per player. Strict: a tournament without a price is not shown.
    @StrictDecimal public var joiningFee: Decimal
    /// Prize; display only, hidden when absent.
    @LenientDecimal public var winningPrice: Decimal?

    @DefaultZero public var noOfTeams: Int
    @DefaultZero public var noOfPlayers: Int
    @DefaultZero public var noOfSubstitute: Int
    @DefaultZero public var teamsPerGroup: Int
    @DefaultFalse public var isFeatured: Bool

    // MARK: Detail only

    @DefaultEmpty public var description: String
    @DefaultEmpty public var rules: String
    @DefaultEmpty public var pitch: String
    @DefaultFalse public var maxAgeEnabled: Bool
    @DefaultZero public var maxAge: Int
    /// Missing (list items) means "not checked", i.e. eligible.
    public var isAgeEligible: Bool?
    /// 1 when the caller holds a paid place.
    @DefaultZero public var joinStatus: Int
    /// 1 when full. The server keeps it 0 until fixtures exist (legacy gate).
    @DefaultZero public var slotStatus: Int
    /// The caller holds a place and the first fixture has not been played.
    @DefaultFalse public var isLeaveTournament: Bool
    @DefaultZero public var joinedPayers: Int
    /// Server-computed capacity: players × teams + substitutes.
    @DefaultZero public var totalPayers: Int
    @DefaultZero public var joinedTeams: Int
    /// The part of the joining fee Champz keeps (detail only).
    @LenientDecimal public var serviceFee: Decimal?
    /// Inclusive day count; nil without a start date.
    public var days: Int?
    @LossyArray public var joinPayerData: [TournamentPlayer]
    @LossyArray public var joinTeamData: [ClubBrief]

    // MARK: - Derived

    public var price: Money {
        Money(joiningFee, currency: Money.defaultCurrency)
    }

    public var prize: Money? {
        winningPrice.map { Money($0, currency: Money.defaultCurrency) }
    }

    /// What one place costs, as the server prices it: the service fee is taken out of
    /// the joining fee, not added on top, so the total is always the joining fee.
    /// (The current app showed fee + joining fee, more than it charged.)
    public var joinPrice: PriceBreakdown {
        let fee = min(serviceFee ?? 0, joiningFee)
        return PriceBreakdown(
            subtotal: Money(joiningFee - fee, currency: Money.defaultCurrency),
            fee: Money(fee, currency: Money.defaultCurrency)
        )
    }

    public var isJoined: Bool {
        joinStatus == 1
    }

    public var isFull: Bool {
        slotStatus == 1
    }

    public var isAgeBlocked: Bool {
        maxAgeEnabled && isAgeEligible == false
    }

    public var isSingleDay: Bool {
        days == 1 || (!startDate.isEmpty && startDate == endDate)
    }

    /// Groups only make sense with a positive group size (the backend default is 0).
    public var groupCount: Int? {
        teamsPerGroup > 0 ? max(1, noOfTeams / teamsPerGroup) : nil
    }

    /// The card's venue line: the ground's name, else its address.
    public var venueText: String {
        guard let ground else { return "" }
        return ground.name.isEmpty ? ground.location : ground.name
    }

    /// The bottom button, following the current app's effective rules.
    public var primaryAction: TournamentAction {
        if isAgeBlocked {
            return .none
        }
        if isJoined, !isLeaveTournament {
            return .none
        }
        if isFull {
            return .full
        }
        return isJoined ? .leave : .join
    }

    public var start: Date? {
        Self.parse(day: startDate, time: startTime)
    }

    public var end: Date? {
        Self.parse(day: endDate, time: endTime)
    }

    static func parse(day: String, time: String) -> Date? {
        guard !day.isEmpty else { return nil }
        return Date.parseAPI(day + "T" + (time.isEmpty ? "00:00:00" : time), assumeLocal: true)
    }
}

public enum TournamentAction: Hashable, Sendable {
    case join, full, leave, none
}

/// Backend `Tournament.Format` (apps/tournaments/models.py:92-99).
public enum TournamentFormat: Int, Sendable, UnknownCaseRepresentable {
    case notSet = 0, league = 1, knockout = 2, leagueAndKnockout = 3, groupAndKnockout = 4
    case unknown = -1
}

/// Backend `Tournament.Entry` (apps/tournaments/models.py:101-105).
public enum TournamentEntry: Int, Sendable, UnknownCaseRepresentable {
    case player = 0, team = 1, unknown = -1
}

/// `GroundBrief`.
public struct TournamentGround: Decodable, Hashable, Sendable {
    @DefaultEmpty public var name: String
    @DefaultEmpty public var location: String
    @DefaultEmpty public var surfaceType: String
    @LenientDecimal public var latitude: Decimal?
    @LenientDecimal public var longitude: Decimal?

    public var coordinate: (latitude: Double, longitude: Double)? {
        guard let latitude, let longitude else { return nil }
        return (Double(truncating: latitude as NSNumber), Double(truncating: longitude as NSNumber))
    }
}

/// `join_payer_data[]`.
public struct TournamentPlayer: Decodable, Hashable, Sendable, Identifiable {
    public let id: PlayerID
    @DefaultEmpty public var name: String
    @DefaultEmpty public var image: String
}

/// `ClubBrief` — a team.
public struct ClubBrief: Decodable, Hashable, Sendable, Identifiable {
    public let id: TeamID
    @DefaultEmpty public var name: String
    @DefaultEmpty public var image: String
}

/// What the "You're in" ticket shows after joining a tournament.
public struct TournamentReceipt: Hashable, Sendable {
    public let tournament: Tournament
    public let joinRequest: JoinRequest
}

/// `POST /tournaments/{id}/leave/` result.
public struct TournamentLeaveResult: Decodable, Hashable, Sendable {
    @LenientDecimal public var refund: Decimal?
}

/// Filters for `GET /tournaments/`, as the current app's filter bar offers them.
public struct TournamentFilter: Hashable, Sendable {
    /// `tournament_type`: a one-day event, or a format code.
    public enum Kind: String, Hashable, Sendable, CaseIterable {
        case oneDay = "1_day"
        case league = "1"
        case knockout = "2"
        case leagueAndKnockout = "3"
        case groupAndKnockout = "4"
    }

    public var thisWeek = false
    public var kind: Kind?

    public init(thisWeek: Bool = false, kind: Kind? = nil) {
        self.thisWeek = thisWeek
        self.kind = kind
    }
}

/// `{"items": [...], "next_cursor": "..."}` — cursor pagination (tournaments, transfer market).
public struct CursorPage<Item: Decodable & Sendable>: Decodable, Sendable {
    @LossyArray public var items: [Item]
    @DefaultEmpty public var nextCursor: String

    public var hasMore: Bool {
        !nextCursor.isEmpty
    }
}
