import Foundation

/// What a checkout pays for. The payment endpoints take `purpose` plus the reference
/// for that purpose. Bookings and top-ups add cases here.
public enum PaymentPurpose: Hashable, Sendable {
    case friendlyGameJoin(JoinRequestID)
    case tournamentJoin(JoinRequestID)
    /// Adding money to my own wallet. The caller names the amount; the server adds any bonus.
    case walletTopup(Money)
    /// The host paying their part of a court booking by card or Apple Pay.
    case courtBooking(BookingID)

    /// `purpose` and its reference field, as the payment endpoints expect them.
    var body: [String: String] {
        switch self {
        case let .friendlyGameJoin(id): ["purpose": "friendly_game_join", "join_request_id": id.raw]
        case let .tournamentJoin(id): ["purpose": "tournament_join", "join_request_id": id.raw]
        case let .walletTopup(amount): ["purpose": "wallet_topup", "amount": amount.apiString]
        case let .courtBooking(id): ["purpose": "court_booking", "booking_id": id.raw]
        }
    }
}
