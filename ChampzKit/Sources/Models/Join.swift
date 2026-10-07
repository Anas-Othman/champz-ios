import Foundation

/// A player from the transfer market, offered in "Pay for a friend".
public struct FriendCandidate: Decodable, Hashable, Sendable, Identifiable {
    public struct Position: Decodable, Hashable, Sendable {
        @DefaultEmpty public var name: String
    }

    public let id: PlayerID
    @DefaultEmpty public var fullName: String
    @DefaultEmpty public var avatarUrl: String
    public var position: Position?
}

/// Everything the registration screen collected, carried to the confirm screen.
public struct JoinDraft: Hashable, Sendable {
    public let match: Match
    public let booking: BookingInfo
    public let friends: [FriendCandidate]
    public let guestEmail: String?
    public let fee: Money

    public var partySize: Int {
        1 + friends.count + (guestEmail == nil ? 0 : 1)
    }

    /// The app's estimate; the server's `charge` on the join response is authoritative.
    public var price: PriceBreakdown {
        PriceBreakdown(unitPrice: match.effectivePrice, quantity: partySize, fee: fee)
    }

    public var subtotal: Money {
        price.subtotal
    }

    public var total: Money {
        price.total
    }
}

/// `POST /games/{id}/join/` response.
public struct JoinRequest: Decodable, Hashable, Sendable {
    public enum PaymentStatus: String, Sendable, UnknownCaseRepresentable {
        case pending, completed, unknown
    }

    public let id: JoinRequestID
    /// "Champz-000123" — shown on the ticket.
    @DefaultEmpty public var uniqueId: String
    @DefaultUnknown public var paymentStatus: PaymentStatus
    @StrictDecimal public var amount: Decimal
    @StrictDecimal public var serviceFee: Decimal
    /// What the player pays: spots + fee.
    @StrictDecimal public var charge: Decimal

    public var chargeMoney: Money {
        Money(charge, currency: Money.defaultCurrency)
    }
}

/// What the Done screen shows.
public struct JoinReceipt: Hashable, Sendable {
    public let match: Match
    public let joinRequest: JoinRequest
}
