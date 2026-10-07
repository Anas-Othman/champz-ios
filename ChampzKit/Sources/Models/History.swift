import Foundation

/// `GET /api/v1/history/` — one row of "My History": a tournament, a game (or round robin)
/// or a court booking, in one flat shape where a kind leaves the others' fields empty.
public struct HistoryItem: Decodable, Hashable, Sendable, Identifiable {
    public enum Kind: String, Sendable, UnknownCaseRepresentable {
        case tournament
        case match
        /// A multi-team game: opens like any game. (The current app opened the booking receipt.)
        case roundRobin = "round_robin"
        case courtBooking = "book_a_court"
        case unknown
    }

    public let id: String
    @DefaultUnknown public var type: Kind
    @DefaultEmpty public var name: String
    @DefaultEmpty public var image: String
    /// "yyyy-MM-dd" and "HH:MM:SS", venue local time.
    @DefaultEmpty public var date: String
    @DefaultEmpty public var startTime: String
    @DefaultEmpty public var endTime: String
    /// Tournament: joining fee. Game: per spot. Booking: what I paid (plus the fee if I hosted).
    @LenientDecimal public var price: Decimal?
    @DefaultEmpty public var location: String
    @DefaultEmpty public var groundName: String
    public var totalPlayerCount: Int?
    public var joinedPlayerCount: Int?
    public var duration: Int?
    @DefaultEmpty public var surfaceType: String
    @DefaultEmpty public var paymentMethod: String
    @DefaultEmpty public var uniqueId: String

    public var isGame: Bool {
        type == .match || type == .roundRobin
    }

    /// A booking's card leads with the venue; everything else with its own name.
    public var title: String {
        type == .courtBooking ? location : name
    }

    public var venueText: String {
        type == .courtBooking ? location : groundName
    }

    public var priceMoney: Money? {
        price.map { Money($0, currency: Money.defaultCurrency) }
    }

    /// "Wed, 07 October | 06:00 pm".
    public var whenText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMMM"
        let day = DateOfBirth.date(from: date).map(formatter.string(from:)) ?? date
        return [day, startTime.isEmpty ? "" : TimeOfDay.label(startTime)].filter { !$0.isEmpty }
            .joined(separator: " | ")
    }

    /// Where tapping it goes.
    public var route: AppRoute? {
        switch type {
        case .tournament: .tournamentDetail(TournamentID(id))
        case .match, .roundRobin: .matchDetail(MatchID(id))
        case .courtBooking: .historyBooking(self)
        case .unknown: nil
        }
    }
}

public struct HistoryPage: Decodable, Sendable {
    @LossyArray public var items: [HistoryItem]
}

/// The tabs and chips on "My History".
public struct HistoryFilter: Hashable, Sendable {
    public enum Tab: String, Hashable, Sendable, CaseIterable {
        case upcoming, previous
    }

    /// One chip at a time narrows what kind of thing is listed (the backend lists only that kind).
    public enum Kind: Hashable, Sendable, CaseIterable {
        case friendly, competitive, oneDay, league, knockout
    }

    public var tab = Tab.upcoming
    public var thisWeek = false
    public var kind: Kind?

    public init(tab: Tab = .upcoming, thisWeek: Bool = false, kind: Kind? = nil) {
        self.tab = tab
        self.thisWeek = thisWeek
        self.kind = kind
    }

    var query: [String: String?] {
        var query: [String: String?] = ["history_type": tab.rawValue, "is_week": thisWeek ? "true" : nil]
        switch kind {
        case .friendly: query["match_type"] = String(MatchCompetition.friendly.rawValue)
        case .competitive: query["match_type"] = String(MatchCompetition.competitive.rawValue)
        case .oneDay: query["tournament_type"] = "1_day"
        case .league: query["tournament_type"] = String(TournamentFormat.league.rawValue)
        case .knockout: query["tournament_type"] = String(TournamentFormat.knockout.rawValue)
        case nil: break
        }
        return query
    }
}
