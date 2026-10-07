import Foundation

/// A friendly or competitive game, as `GET /games/`, `GET /games/{id}/` and the home feed
/// describe it. One struct for list and detail: the detail adds `teams`, the list leaves it empty.
public struct Match: Decodable, Hashable, Sendable, Identifiable {
    public var id: MatchID
    @DefaultEmpty public var title: String
    @DefaultEmpty public var description: String
    @DefaultEmpty public var tournamentImage: String
    public var createdBy: MatchOrganizer?

    /// `type`: 0 = standard two-team game, 1 = multi-team (legacy WSO).
    @DefaultUnknown public var type: MatchKind
    @DefaultUnknown public var matchType: MatchCompetition
    @DefaultEmpty public var matchTypeLabel: String
    @DefaultUnknown public var status: MatchStatus
    @DefaultUnknown public var slotStatus: SlotStatus

    @DefaultEmpty public var venueId: String
    @DefaultEmpty public var venueName: String
    @DefaultEmpty public var courtName: String
    @DefaultEmpty public var courtDetails: String
    @DefaultEmpty public var location: String
    @DefaultEmpty public var address: String
    @DefaultEmpty public var surfaceType: String
    @LenientDecimal public var latitude: Decimal?
    @LenientDecimal public var longitude: Decimal?
    @DefaultZero public var noOfCourts: Int
    @DefaultEmpty public var contactNumber: String

    /// `yyyy-MM-dd` and `HH:mm:ss`, in the venue's local time.
    @DefaultEmpty public var date: String
    @DefaultEmpty public var startTime: String
    @DefaultZero public var duration: Int

    @DefaultZero public var noOfPlayers: Int
    @DefaultZero public var substitutes: Int
    @DefaultZero public var totalPlayers: Int
    @DefaultZero public var joinedPlayerCount: Int
    @DefaultFalse public var joinStatus: Bool
    @DefaultFalse public var isJoinWaitingList: Bool

    /// Null means free (legacy data); the discount applies when `discountKey == "1"`.
    @LenientDecimal public var price: Decimal?
    @DefaultEmpty public var discountKey: String
    @LenientDecimal public var discountPrice: Decimal?
    @DefaultFalse public var isPaid: Bool
    @DefaultFalse public var isByChampz: Bool

    /// Backend `automatic_teams_created`: players have been dealt into real teams.
    /// Until then the server parks everyone on team 1, so multi-team rosters show one flat list.
    @DefaultFalse public var automaticTeamsCreated: Bool

    @LossyArray public var teams: [MatchTeam]

    // MARK: - Derived

    public var isCancelled: Bool {
        status == .cancelled
    }

    public var isFinished: Bool {
        status == .completed
    }

    public var isCompetitive: Bool {
        matchType == .competitive
    }

    /// The amount one spot costs today.
    public var effectivePrice: Money {
        let amount = discountKey == "1" ? (discountPrice ?? price ?? 0) : (price ?? 0)
        return Money(amount, currency: Money.defaultCurrency)
    }

    public var isFree: Bool {
        effectivePrice.isZero
    }

    public var spotsLeft: Int {
        max(0, totalPlayers - joinedPlayerCount)
    }

    /// The card turns its counter red when three or fewer spots remain.
    public var isAlmostFull: Bool {
        totalPlayers > 0 && joinedPlayerCount >= totalPlayers - 3
    }

    public var isLastSpot: Bool {
        totalPlayers > 0 && joinedPlayerCount == totalPlayers - 1
    }

    /// How the "who's playing" screen lays players out (team_roster_screen.dart, commit abbbb29).
    public var rosterLayout: RosterLayout {
        switch type {
        case .multiTeam, .unknown:
            automaticTeamsCreated ? .groupedByTeam : .allPlayers
        case .standard:
            .teamSheet
        }
    }

    /// Everyone on every team, in team order.
    public var allPlayers: [MatchPlayer] {
        teams.flatMap(\.players)
    }

    /// What the big bottom button does (same rules as the current app's status helper).
    public var primaryAction: MatchAction {
        if joinStatus, !isJoinWaitingList {
            return .leave
        }
        if isJoinWaitingList {
            return .leaveWaitingList
        }
        if slotStatus == .waitingList || (slotStatus == .full && !joinStatus) {
            return slotStatus == .waitingList ? .joinWaitingList : .full
        }
        return .join
    }

    /// Kickoff as an absolute instant, interpreted in the device's time zone until venues carry one.
    public var kickoff: Date? {
        Date.parseAPI(date + "T" + (startTime.isEmpty ? "00:00:00" : startTime), assumeLocal: true)
    }

    public var coordinate: (latitude: Double, longitude: Double)? {
        guard let latitude, let longitude else { return nil }
        return (Double(truncating: latitude as NSNumber), Double(truncating: longitude as NSNumber))
    }
}

public enum RosterLayout: Hashable, Sendable {
    /// Standard two-team game: Team A / Team B.
    case teamSheet
    /// Multi-team game before teams are dealt: one grid of everyone.
    case allPlayers
    /// Multi-team game after `automatic_teams_created`: a grid per team.
    case groupedByTeam
}

public enum MatchAction: Hashable, Sendable {
    case join, leave, joinWaitingList, leaveWaitingList, full
}

public enum MatchKind: Int, Sendable, UnknownCaseRepresentable {
    case standard = 0, multiTeam = 1, unknown = -1
}

/// Backend `Match.Kind` (apps/games/models.py): COMPETITIVE = 1, FRIENDLY = 2.
public enum MatchCompetition: Int, Sendable, UnknownCaseRepresentable {
    case competitive = 1, friendly = 2, unknown = -1
}

public enum MatchStatus: Int, Sendable, UnknownCaseRepresentable {
    case scheduled = 0, live = 1, completed = 2, cancelled = 3, unknown = -1
}

public enum SlotStatus: Int, Sendable, UnknownCaseRepresentable {
    case open = 0, full = 1, waitingList = 2, unknown = -1
}

public struct MatchOrganizer: Decodable, Hashable, Sendable, Identifiable {
    public let id: PlayerID
    @DefaultEmpty public var name: String
    @DefaultEmpty public var email: String
    @DefaultEmpty public var phone: String
    @DefaultEmpty public var image: String
}

public struct MatchTeam: Decodable, Hashable, Sendable, Identifiable {
    public let id: String
    @DefaultZero public var number: Int
    @DefaultEmpty public var name: String
    @DefaultZero public var score: Int
    @LossyArray public var players: [MatchPlayer]
    @DefaultZero public var remainingSlots: Int
}

public struct MatchPlayer: Decodable, Hashable, Sendable, Identifiable {
    public let id: String
    @DefaultEmpty public var playerId: String
    @DefaultEmpty public var name: String
    @DefaultEmpty public var image: String
    @DefaultEmpty public var position: String
    @DefaultFalse public var isGuest: Bool
    @DefaultZero public var ordering: Int
    @DefaultZero public var goals: Int
}

/// `GET /games/leave-reasons/`.
public struct LeaveReason: Decodable, Hashable, Sendable, Identifiable {
    public let id: Int
    @DefaultEmpty public var reason: String

    public init(id: Int, reason: String) {
        self.id = id
        self.reason = reason
    }
}

/// `POST /games/{id}/leave/` result: what came back to the wallet and how many spots opened.
public struct LeaveResult: Decodable, Hashable, Sendable {
    @LenientDecimal public var refunded: Decimal?
    @DefaultZero public var slotsFreed: Int
}

/// `GET /home/` — the home tab in one call.
public struct HomeFeed: Decodable, Hashable, Sendable {
    public struct Player: Decodable, Hashable, Sendable {
        @DefaultEmpty public var fullName: String
        @DefaultEmpty public var avatarUrl: String
    }

    public var player: Player?
    @LenientDecimal public var walletBalance: Decimal?
    @DefaultEmpty public var currency: String
    @LossyArray public var upcomingMatches: [Match]
    /// Approved, upcoming, by start date — at most four.
    @LossyArray public var tournaments: [Tournament]

    public var balance: Money {
        Money(walletBalance ?? 0, currency: currency.isEmpty ? Money.defaultCurrency : currency)
    }
}

/// Filters for `GET /games/`, mirroring the current app's filter sheet (dates, type).
public struct MatchFilter: Hashable, Sendable {
    public enum Dates: Hashable, Sendable {
        case any
        case thisWeek
        case range(from: String, to: String) // yyyy-MM-dd
    }

    public var dates: Dates = .any
    public var competition: MatchCompetition?

    public init(dates: Dates = .any, competition: MatchCompetition? = nil) {
        self.dates = dates
        self.competition = competition
    }

    public static let `default` = MatchFilter()
}
