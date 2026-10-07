import Foundation

/// Endpoints under /api/v1/tournaments/.
enum TournamentsAPI {
    static func list(_ filter: TournamentFilter, cursor: String?) -> Endpoint<CursorPage<Tournament>> {
        var query: [String: String?] = ["limit": "20", "cursor": cursor, "tournament_type": filter.kind?.rawValue]
        if filter.thisWeek {
            // Monday–Sunday of the current week, as the current app sends it.
            let calendar = Calendar(identifier: .iso8601)
            if let week = calendar.dateInterval(of: .weekOfYear, for: .now) {
                query["date_from"] = week.start.apiDay
                query["date_to"] = calendar.date(byAdding: .day, value: 6, to: week.start)?.apiDay
            }
        }
        return Endpoint(.get, "/api/v1/tournaments/").query(query)
    }

    static func detail(_ id: TournamentID) -> Endpoint<Tournament> {
        Endpoint(.get, "/api/v1/tournaments/\(id.raw)/")
    }

    static func join(
        _ id: TournamentID,
        _ booking: BookingInfo,
        method: PurchasePaymentMethod,
        idempotencyKey: String
    ) -> Endpoint<JoinRequest> {
        Endpoint(.post, "/api/v1/tournaments/\(id.raw)/join/", idempotencyKey: idempotencyKey)
            .json(TournamentJoinBody(booking, method: method))
    }

    static func leave(_ id: TournamentID, reason: String) -> Endpoint<TournamentLeaveResult> {
        Endpoint(.post, "/api/v1/tournaments/\(id.raw)/leave/").json(["reason": reason])
    }
}

/// `POST /tournaments/{id}/join/` body. No `club_id`: the player registers on their own
/// (the free-agent pool). The server prices it; no amount is sent.
struct TournamentJoinBody: Encodable {
    let paymentMethod: String
    let bookingName: String
    let bookingEmail: String
    let bookingMobileNo: String

    init(_ booking: BookingInfo, method: PurchasePaymentMethod) {
        paymentMethod = method.rawValue
        bookingName = booking.trimmedName
        bookingEmail = booking.trimmedEmail
        bookingMobileNo = booking.formattedPhone
    }
}

public protocol TournamentRepository: Sendable {
    func tournaments(_ filter: TournamentFilter, cursor: String?) async throws(AppError) -> CursorPage<Tournament>
    func tournament(_ id: TournamentID) async throws(AppError) -> Tournament
    func leave(_ id: TournamentID, reason: String) async throws(AppError) -> TournamentLeaveResult
    /// Takes a place. `wallet` completes here; `online` is pending until checkout settles.
    func join(
        _ id: TournamentID,
        _ booking: BookingInfo,
        method: PurchasePaymentMethod,
        idempotencyKey: String
    ) async throws(AppError) -> JoinRequest
}

public struct LiveTournamentRepository: TournamentRepository {
    let http: any HTTPClientProtocol

    public init(http: any HTTPClientProtocol) {
        self.http = http
    }

    public func tournaments(
        _ filter: TournamentFilter,
        cursor: String?
    ) async throws(AppError) -> CursorPage<Tournament> {
        try await http.send(TournamentsAPI.list(filter, cursor: cursor))
    }

    public func tournament(_ id: TournamentID) async throws(AppError) -> Tournament {
        try await http.send(TournamentsAPI.detail(id))
    }

    public func leave(_ id: TournamentID, reason: String) async throws(AppError) -> TournamentLeaveResult {
        try await http.send(TournamentsAPI.leave(id, reason: reason))
    }

    public func join(
        _ id: TournamentID,
        _ booking: BookingInfo,
        method: PurchasePaymentMethod,
        idempotencyKey: String
    ) async throws(AppError) -> JoinRequest {
        try await http.send(TournamentsAPI.join(id, booking, method: method, idempotencyKey: idempotencyKey))
    }
}
