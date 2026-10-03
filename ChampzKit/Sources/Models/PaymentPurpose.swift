import Foundation

/// What is being paid for. A feature hands one of these to the checkout sheet and is
/// done; the Payments module handles everything after (guide, section 9).
/// Lives in Domain so Navigation can carry it without importing Payments.
public enum PaymentPurpose: Hashable, Sendable {
    case friendlyGameJoin(gameID: MatchID, spots: Int)
    case tournamentJoin(tournamentID: TournamentID, teamID: TeamID?)
    case courtBookingAccept(bookingID: BookingID)
    case courtBookingCreate(BookingDraft)
    case walletTopUp(Money)
    case walletTransfer(to: PlayerID, amount: Money)

    /// The `purpose` string the payment endpoints expect. Transfers have none.
    public var backendPurpose: String? {
        switch self {
        case .friendlyGameJoin: "friendly_game_join"
        case .tournamentJoin: "tournament_join"
        case .courtBookingAccept, .courtBookingCreate: "court_booking"
        case .walletTopUp: "wallet_topup"
        case .walletTransfer: nil
        }
    }

    /// Methods the current app offers for this purpose (PAYMENT_FEATURE_DOCS_V2.md, section 6).
    public var allowedMethods: Set<PaymentMethod> {
        switch self {
        case .friendlyGameJoin, .tournamentJoin, .courtBookingAccept: [.wallet, .card, .cash, .applePay]
        case .courtBookingCreate: [.card, .cash]
        case .walletTopUp: [.card, .applePay]
        case .walletTransfer: [.wallet, .card]
        }
    }
}

public enum PaymentMethod: String, Hashable, Sendable, CaseIterable {
    case wallet
    case card
    case cash
    case applePay = "apple_pay"
}

/// The minimum a new court booking needs before payment. Filled in by the booking feature.
public struct BookingDraft: Hashable, Sendable {
    public let courtID: CourtID
    public let start: Date
    public let durationMinutes: Int

    public init(courtID: CourtID, start: Date, durationMinutes: Int) {
        self.courtID = courtID
        self.start = start
        self.durationMinutes = durationMinutes
    }
}
