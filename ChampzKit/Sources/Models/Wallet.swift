import Foundation

/// `GET /api/v1/wallet/transactions/` — one movement on my wallet, newest first.
public struct LedgerEntry: Decodable, Hashable, Sendable, Identifiable {
    public let id: String
    /// Signed: positive came in, negative went out.
    @StrictDecimal public var amount: Decimal
    @DefaultEmpty public var currency: String
    @DefaultUnknown public var reason: LedgerReason
    @DefaultEmpty public var createdAt: String

    public var money: Money {
        Money(amount, currency: currency.isEmpty ? Money.defaultCurrency : currency)
    }

    public var isCredit: Bool {
        amount >= 0
    }

    /// "+ 50 QR" / "- 175 QR".
    public var signedText: String {
        (isCredit ? "+ " : "- ") + Money(abs(amount), currency: money.currency).compact
    }

    public var date: Date? {
        Date.parseAPI(createdAt)
    }
}

/// Why money moved (`LedgerEntry.Reason` on the backend).
public enum LedgerReason: String, Sendable, UnknownCaseRepresentable {
    case matchFee = "match_fee"
    case tournamentServiceFee = "t_service_fee"
    case courtServiceFee = "bc_service_fee"
    case gameServiceFee = "fg_service_fee"
    case bookCourt = "book_court"
    case commission
    case refund
    case settlement
    case topup
    case topupBonus = "topup_bonus"
    case transfer
    case legacyImport = "legacy_import"
    case accountClosure = "account_closure"
    case unclaimedCredit = "unclaimed_credit"
    case adminAdjustment = "admin_adjustment"
    case openingFloor = "opening_floor"
    case openingAlignment = "opening_alignment"
    case unknown
}

/// `GET /api/v1/wallet/topup/bonus-preview/?amount=` — advisory: the server recomputes it when the payment lands.
public struct TopupBonus: Decodable, Hashable, Sendable {
    @StrictDecimal public var amount: Decimal
    @StrictDecimal public var bonus: Decimal
    @StrictDecimal public var total: Decimal
    @DefaultFalse public var enabled: Bool
    @DefaultEmpty public var currency: String

    public var bonusMoney: Money {
        Money(bonus, currency: currency.isEmpty ? Money.defaultCurrency : currency)
    }

    public var totalMoney: Money {
        Money(total, currency: currency.isEmpty ? Money.defaultCurrency : currency)
    }

    /// Worth showing only when bonuses are on and this amount earns one.
    public var hasBonus: Bool {
        enabled && bonus > 0
    }
}

/// What the "Top up success" ticket shows.
public struct TopupReceipt: Hashable, Sendable {
    public let amount: Money
    /// The bonus expected at the time of paying; nil when there was none.
    public let bonus: Money?
}
