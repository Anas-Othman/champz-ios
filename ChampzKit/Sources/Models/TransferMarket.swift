import Foundation

/// A transfer-market card: the public player card plus their goals and games.
/// The backend sends one flat object; `player` is decoded from that same object, so the
/// market reuses `PublicPlayer` (and its age, nationality…) instead of repeating its fields.
public struct MarketPlayer: Decodable, Hashable, Sendable, Identifiable {
    public let player: PublicPlayer
    public var isCaptain: Bool
    public var goals: Int
    public var matchesPlayed: Int

    public var id: PlayerID {
        player.id
    }

    private enum CodingKeys: String, CodingKey {
        case isCaptain, goals, matchesPlayed
    }

    public init(from decoder: any Decoder) throws {
        player = try PublicPlayer(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isCaptain = (try? container.decodeIfPresent(Bool.self, forKey: .isCaptain)) ?? false
        goals = (try? container.decodeIfPresent(Int.self, forKey: .goals)) ?? 0
        matchesPlayed = (try? container.decodeIfPresent(Int.self, forKey: .matchesPlayed)) ?? 0
    }

    /// "Striker | Age 24", whichever parts are known.
    public var positionAndAge: String {
        var parts: [String] = []
        if let position = player.position?.name, !position.isEmpty {
            parts.append(position)
        }
        if let age = player.age() {
            parts.append("\(String(localized: L10n.TransferMarket.age)) \(age)")
        }
        return parts.joined(separator: " | ")
    }
}

/// The "Our Talents" filters. Empty means everyone.
/// (The current app always sent ages 13–80 once you had typed anything, so clearing the
/// search never brought the full list back and older or younger players were hidden.)
public struct MarketFilter: Hashable, Sendable {
    public static let ageBounds: ClosedRange<Int> = 0 ... 100

    public var search = ""
    public var position: Position?
    public var nationality: Nationality?
    /// nil = any age.
    public var ages: ClosedRange<Int>?

    public init(
        search: String = "",
        position: Position? = nil,
        nationality: Nationality? = nil,
        ages: ClosedRange<Int>? = nil
    ) {
        self.search = search
        self.position = position
        self.nationality = nationality
        self.ages = ages
    }

    /// How many sheet filters are on (search not counted); drives the badge on the filter button.
    public var activeCount: Int {
        [position != nil, nationality != nil, ages != nil].filter(\.self).count
    }

    /// The sheet's part only, with the search kept.
    public func clearingSheetFilters() -> MarketFilter {
        MarketFilter(search: search)
    }

    var query: [String: String?] {
        [
            "search": search.trimmingCharacters(in: .whitespaces).isEmpty ? nil : search
                .trimmingCharacters(in: .whitespaces),
            "position_id": position?.id.raw,
            "nationality_id": nationality?.id.raw,
            "from_age": ages.map { String($0.lowerBound) },
            "to_age": ages.map { String($0.upperBound) },
        ]
    }
}
