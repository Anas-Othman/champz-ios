import Foundation

/// How a match's date and time read on screen (same shapes as the current app).
public extension Match {
    /// Card: "3 Oct | 8:00 pm".
    var kickoffCardText: String {
        guard let kickoff else { return date }
        return kickoff.formatted(.dateTime.day().month(.abbreviated)) + " | " + kickoffTimeText
    }

    /// Detail: "10 oct, 2026 - 08:00 pm" — `formatDateTimeWithLowercase` in the current app.
    var kickoffDetailText: String {
        guard let kickoff else { return date }
        return Self.detailFormatter.string(from: kickoff).lowercased()
    }

    private static let detailFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "dd MMM, yyyy - hh:mm a"
        return formatter
    }()

    var kickoffDateText: String {
        kickoff?.formatted(.dateTime.day().month(.abbreviated).year()) ?? date
    }

    var kickoffTimeText: String {
        kickoff?.formatted(.dateTime.hour().minute()).lowercased() ?? startTime
    }
}

/// Sample for previews and tests.
public extension Match {
    // swiftlint:disable line_length
    static let preview: Match = {
        let json = """
        {"id": "01J9MATCH0000000000000001", "title": "Friday Night 5s", "tournament_image": "",
         "created_by": {"id": "01J9PLAYER000000000000001", "name": "Anas", "email": null, "phone": "+97455512345", "image": null},
         "type": 0, "match_type": 2, "match_type_label": "Friendly", "status": 0, "slot_status": 0,
         "venue_name": "Aspire Zone", "court_name": "Court 3", "location": "Al Waab, Doha", "latitude": "25.2600", "longitude": "51.4400",
         "no_of_courts": 1, "date": "2026-10-10", "start_time": "20:00:00", "total_players": 10, "joined_player_count": 7,
         "join_status": false, "is_join_waiting_list": false, "price": "30.00", "discount_key": "0", "is_paid": true, "is_by_champz": true,
         "description": "Bring both shirts.", "teams": [{"id": "t1", "number": 1, "name": "Team A", "players": [{"id": "p1", "player_id": "01J9PLAYER000000000000002", "name": "Omar", "image": "", "position": "GK", "is_guest": false, "ordering": 1}], "remaining_slots": 4}]}
        """
        // swiftlint:disable:next force_try
        return try! JSONDecoder.api().decode(Match.self, from: Data(json.utf8))
    }()
    // swiftlint:enable line_length
}
