import Foundation

/// `GET /api/v1/players/{id}/stats/` — any player's card and statistics.
/// The same response feeds My Stats (with the signed-in player's id) and every other player's profile.
public struct PlayerStats: Decodable, Hashable, Sendable {
    public let player: PublicPlayer
    public let statistics: PlayerStatistics
}

/// A player as everyone sees them. No contact details.
public struct PublicPlayer: Decodable, Hashable, Sendable, Identifiable {
    public let id: PlayerID
    @DefaultEmpty public var fullName: String
    @DefaultEmpty public var avatarUrl: String
    /// "yyyy-MM-dd", empty when unset.
    @DefaultEmpty public var dateOfBirth: String
    public var nationality: Nationality?
    public var position: Position?
    /// Open to transfer offers.
    @DefaultFalse public var isAvailable: Bool
    @DefaultEmpty public var clubName: String
    /// When the player joined Champz.
    @DefaultEmpty public var debut: String

    /// Whole years today; nil without a date of birth (the current app showed "Age 0").
    public func age(on today: Date = .now) -> Int? {
        guard let born = DateOfBirth.date(from: dateOfBirth) else { return nil }
        return Calendar(identifier: .gregorian).dateComponents([.year], from: born, to: today).year
    }

    /// "MAR, 2024".
    public var debutText: String {
        guard let date = Date.parseAPI(debut) else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM, yyyy"
        return formatter.string(from: date).uppercased()
    }
}

/// Match record and goal tally. Every count is server-computed; zero means "no history".
public struct PlayerStatistics: Decodable, Hashable, Sendable {
    @DefaultZero public var matchesPlayed: Int
    @DefaultZero public var matchesWon: Int
    @DefaultZero public var matchesLost: Int
    @DefaultZero public var tournamentsWon: Int
    /// The server's total. (My Stats in the current app added the three types itself, so the two screens could
    /// disagree.)
    @DefaultZero public var goalsTotal: Int
    @DefaultZero public var goalsFriendlies: Int
    @DefaultZero public var goalsCompetitive: Int
    @DefaultZero public var goalsTournaments: Int
    @DefaultFalse public var isCaptain: Bool
    @LossyArray public var transfers: [TransferRecord]
    /// Empty until the awards feature lands.
    @LossyArray public var accolades: [Accolade]
}

public struct TransferRecord: Decodable, Hashable, Sendable {
    @DefaultEmpty public var transferredFrom: String
    @DefaultEmpty public var transferredTo: String
    @DefaultEmpty public var date: String
}

public struct Accolade: Decodable, Hashable, Sendable {
    @DefaultEmpty public var name: String
    @DefaultEmpty public var tournamentName: String
}

public extension PlayerStats {
    // swiftlint:disable line_length
    /// Sample for previews and tests.
    static let preview: PlayerStats = .decodePreview("""
    {"player": {"id": "01J9PLAYER0000000000000001", "full_name": "Anas Ezzat", "avatar_url": "", "date_of_birth": "1995-03-07",
      "nationality": {"id": "c2", "code": "EG", "name": "Egypt", "nationality": "Egyptian"},
      "position": {"id": "p1", "name": "Striker"}, "is_available": true, "club_name": "Falcons", "debut": "2024-03-12T10:00:00Z"},
     "statistics": {"matches_played": 42, "matches_won": 25, "matches_lost": 12, "tournaments_won": 2,
      "goals_total": 31, "goals_friendlies": 18, "goals_competitive": 9, "goals_tournaments": 4, "is_captain": false,
      "transfers": [{"transferred_from": "Eagles", "transferred_to": "Falcons", "date": "2025-01-10"}],
      "accolades": [{"name": "Top Scorer", "tournament_name": "Doha Winter Cup"}]}}
    """)
    // swiftlint:enable line_length

    private static func decodePreview(_ json: String) -> PlayerStats {
        // swiftlint:disable:next force_try
        try! JSONDecoder.api().decode(PlayerStats.self, from: Data(json.utf8))
    }
}
