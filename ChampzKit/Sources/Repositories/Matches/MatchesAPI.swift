import Foundation

/// Endpoints under /api/v1/games/ and /api/v1/home/.
enum MatchesAPI {
    static func list(_ filter: MatchFilter, page: Page) -> Endpoint<PaginatedResponse<Match>> {
        var query: [String: String?] = [
            "page": String(page.number),
            "page_size": String(page.size),
            "match_type": filter.competition.map { String($0.rawValue) },
        ]
        switch filter.dates {
        case .any:
            break
        case .thisWeek:
            let today = Date()
            query["date_from"] = today.apiDay
            query["date_to"] = Calendar.current.date(byAdding: .day, value: 7, to: today)?.apiDay
        case let .range(from, to):
            query["date_from"] = from
            query["date_to"] = to
        }
        return Endpoint(.get, "/api/v1/games/").query(query)
    }

    static func detail(_ id: MatchID) -> Endpoint<Match> {
        Endpoint(.get, "/api/v1/games/\(id.raw)/")
    }

    static func leaveReasons() -> Endpoint<[LeaveReason]> {
        Endpoint(.get, "/api/v1/games/leave-reasons/")
    }

    static func leave(_ id: MatchID, reason: String) -> Endpoint<LeaveResult> {
        Endpoint(.post, "/api/v1/games/\(id.raw)/leave/").json(["reason": reason])
    }

    static func joinWaitingList(_ id: MatchID) -> Endpoint<NoContent> {
        Endpoint(.post, "/api/v1/games/\(id.raw)/waiting-list/")
    }

    static func leaveWaitingList(_ id: MatchID) -> Endpoint<NoContent> {
        Endpoint(.delete, "/api/v1/games/\(id.raw)/waiting-list/")
    }

    static func join(
        _ id: MatchID,
        _ draft: JoinDraft,
        method: PurchasePaymentMethod,
        idempotencyKey: String
    ) -> Endpoint<JoinRequest> {
        Endpoint(.post, "/api/v1/games/\(id.raw)/join/", idempotencyKey: idempotencyKey)
            .json(JoinBody(draft, method: method))
    }

    static func home() -> Endpoint<HomeFeed> {
        Endpoint(.get, "/api/v1/home/")
    }
}

/// `POST /games/{id}/join/` body. The server prices it; no amount is sent.
/// No `team_number`: the server picks the team (the current app's pre-fetch blocked valid joins).
struct JoinBody: Encodable {
    struct Guest: Encodable {
        let name: String
        let email: String
    }

    let paymentMethod: String
    let friendIds: [String]?
    let guests: [Guest]?
    let bookingName: String
    let bookingEmail: String
    let bookingMobileNo: String

    init(_ draft: JoinDraft, method: PurchasePaymentMethod) {
        paymentMethod = method.rawValue
        friendIds = draft.friends.isEmpty ? nil : draft.friends.map(\.id.raw)
        guests = draft.guestEmail.map { [Guest(name: "Guest", email: $0)] }
        bookingName = draft.booking.trimmedName
        bookingEmail = draft.booking.trimmedEmail
        bookingMobileNo = draft.booking.formattedPhone
    }
}

extension Date {
    /// `yyyy-MM-dd` for query parameters and bodies, as a calendar day in the phone's time zone.
    /// (`.iso8601` alone formats in UTC, which turns local midnight in Doha into the day before.)
    var apiDay: String {
        formatted(Date.ISO8601FormatStyle(timeZone: .current).year().month().day().dateSeparator(.dash))
    }
}
