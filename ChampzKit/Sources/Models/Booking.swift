import Foundation

/// `POST /bookings/` and `GET /bookings/{id}/` — a court booking. Every figure is the server's.
public struct CourtBooking: Decodable, Hashable, Sendable, Identifiable {
    public enum PaymentType: String, Sendable, UnknownCaseRepresentable {
        case single, split, unknown
    }

    public let id: BookingID
    /// "CRT-000412" — the bill id on the ticket.
    @DefaultEmpty public var uniqueId: String
    @DefaultEmpty public var courtName: String
    @DefaultEmpty public var venueName: String
    @DefaultEmpty public var date: String
    @DefaultEmpty public var startTime: String
    @DefaultEmpty public var endTime: String
    @DefaultZero public var duration: Int
    @DefaultUnknown public var paymentType: PaymentType
    /// The court's price, all players together.
    @LenientDecimal public var grossPrice: Decimal?
    /// Charged to the host only.
    @LenientDecimal public var serviceFee: Decimal?
    @DefaultEmpty public var paymentStatus: String
    /// What I still owe (my share + the fee if I am host); nil when nothing.
    @LenientDecimal public var payableAmount: Decimal?
    public var owner: BookingParticipant?
    @LossyArray public var participants: [BookingParticipant]

    /// "Thu, 8 Oct · 06:00 pm – 07:30 pm".
    public var whenText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, d MMM"
        let day = DateOfBirth.date(from: date).map(formatter.string(from:)) ?? date
        return "\(day) · \(TimeOfDay.label(startTime)) – \(TimeOfDay.label(endTime))"
    }

    /// What I still owe on it (the server's figure).
    public var payable: Money {
        Money(payableAmount ?? 0, currency: Money.defaultCurrency)
    }

    /// The host's charge: their share plus the service fee.
    public var hostCharge: Money {
        Money((owner?.amountDue ?? 0) + (serviceFee ?? 0), currency: Money.defaultCurrency)
    }
}

public struct BookingParticipant: Decodable, Hashable, Sendable, Identifiable {
    public let id: String
    @DefaultEmpty public var userId: String
    @DefaultEmpty public var name: String
    @DefaultFalse public var isOwner: Bool
    @LenientDecimal public var amountDue: Decimal?
    @LenientDecimal public var amountPaid: Decimal?
    @DefaultEmpty public var paymentStatus: String
    /// "pending", "accepted", "declined".
    @DefaultEmpty public var inviteResponseStatus: String

    public var hasAnswered: Bool {
        inviteResponseStatus == "accepted" || inviteResponseStatus == "declined" || paymentStatus == "paid"
    }
}

/// Everything the booking screens collected, carried from the venue to the confirm screen.
public struct CourtBookingDraft: Hashable, Sendable {
    public let venue: Venue
    public let court: PricedCourt
    /// The day, at midnight in the phone's calendar.
    public let day: Date
    /// "HH:MM".
    public let start: String
    public let duration: Int
    public var booking = BookingInfo()
    public var friends: [FriendCandidate] = []
    /// The signed-in player, sent as the host participant.
    public var hostID: PlayerID?
    /// The server's `book_of_court_fee`, charged to the host.
    public var fee = Money.zero(Money.defaultCurrency)

    public init(venue: Venue, court: PricedCourt, day: Date, start: String, duration: Int) {
        self.venue = venue
        self.court = court
        self.day = day
        self.start = start
        self.duration = duration
    }

    public var isSplit: Bool {
        !friends.isEmpty
    }

    /// The host's share, as the server splits it: equal shares rounded to 2 places,
    /// with any leftover on the host so the shares add up to the price.
    /// Display only; the server's booking is authoritative.
    public var hostShare: Money {
        let gross = court.price
        guard isSplit else { return court.priceMoney }
        let count = Decimal(friends.count + 1)
        var share = gross / count
        var rounded = Decimal()
        NSDecimalRound(&rounded, &share, 2, .plain)
        let remainder = gross - rounded * count
        return Money(rounded + remainder, currency: Money.defaultCurrency)
    }

    /// What each friend will be asked to pay.
    public var friendShare: Money {
        guard isSplit else { return .zero(Money.defaultCurrency) }
        var share = court.price / Decimal(friends.count + 1)
        var rounded = Decimal()
        NSDecimalRound(&rounded, &share, 2, .plain)
        return Money(rounded, currency: Money.defaultCurrency)
    }

    /// What the host pays now.
    public var price: PriceBreakdown {
        PriceBreakdown(subtotal: hostShare, fee: fee)
    }

    public var endMinutes: Int {
        (TimeOfDay.minutes(start) ?? 0) + duration
    }

    /// "Thu, 5 Mar · 06:00 pm – 07:30 pm".
    public var whenText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, d MMM"
        return "\(formatter.string(from: day)) · \(TimeOfDay.label(start)) – \(TimeOfDay.label(minutes: endMinutes))"
    }
}

/// What the ticket shows after paying my share of someone's booking.
public struct BookingInviteReceipt: Hashable, Sendable {
    public let booking: CourtBooking
    public let paid: Money
}

/// What the "Booking confirmed" ticket shows.
public struct CourtBookingReceipt: Hashable, Sendable {
    public let draft: CourtBookingDraft
    public let booking: CourtBooking

    /// The server's court name, else the one picked.
    public var courtName: String {
        booking.courtName.isEmpty ? draft.court.name : booking.courtName
    }
}
