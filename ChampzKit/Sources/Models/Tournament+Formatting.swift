import Foundation

public extension Tournament {
    /// Card: "Thu, 05 March | 06:00 pm" (current app's card format).
    var cardDateText: String {
        let day = start.map { Self.format($0, "EEE, dd MMMM") } ?? startDate
        return [day, startTimeText].filter { !$0.isEmpty }.joined(separator: " | ")
    }

    /// "Thu, 5 Mar".
    var startDayText: String {
        start.map { Self.format($0, "EEE, d MMM") } ?? startDate
    }

    var endDayText: String {
        end.map { Self.format($0, "EEE, d MMM") } ?? endDate
    }

    /// "06:00 pm" — the current app showed the raw "18:00:00" here.
    var startTimeText: String {
        start.flatMap { startTime.isEmpty ? nil : Self.format($0, "hh:mm a").lowercased() } ?? ""
    }

    var endTimeText: String {
        end.flatMap { endTime.isEmpty ? nil : Self.format($0, "hh:mm a").lowercased() } ?? ""
    }

    /// "5 V 5".
    var teamSizeText: String {
        "\(noOfPlayers) V \(noOfPlayers)"
    }

    private static func format(_ date: Date, _ pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}

/// Sample for previews and tests.
public extension Tournament {
    // swiftlint:disable line_length
    static let preview: Tournament = {
        let json = """
        {"id": "01J9TOURN000000000000001", "name": "Doha Winter Cup", "image": "", "format": 4, "type": 0,
         "ground": {"id": "g1", "name": "Aspire Zone", "location": "Al Waab, Doha", "latitude": "25.2600000", "longitude": "51.4400000", "surface_type": "Synthetic"},
         "start_date": "2026-11-05", "end_date": "2026-11-07", "start_time": "18:00:00", "end_time": "22:00:00",
         "joining_fee": "50.00", "winning_price": "500.00", "no_of_teams": 8, "no_of_players": 5, "no_of_substitute": 2, "teams_per_group": 4,
         "description": "Three days, eight teams.", "rules": "FIFA rules.", "pitch": "Synthetic", "days": 3,
         "join_status": 0, "slot_status": 0, "joined_payers": 12, "total_payers": 42, "joined_teams": 2,
         "join_payer_data": [{"id": "p1", "name": "Omar", "image": ""}], "join_team_data": [{"id": "c1", "name": "Falcons", "image": ""}]}
        """
        // swiftlint:disable:next force_try
        return try! JSONDecoder.api().decode(Tournament.self, from: Data(json.utf8))
    }()
    // swiftlint:enable line_length
}
