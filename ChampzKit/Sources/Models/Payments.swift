import Foundation

/// How a purchase is paid, as the purchase endpoints take it (`payment_method`).
/// Card and Apple Pay are `online`: the purchase stays pending until checkout settles.
public enum PurchasePaymentMethod: String, Hashable, Sendable {
    case wallet, cash, online
}

/// What a purchase costs before payment: the items plus the service fee.
/// Every paid flow builds one and hands it to `Checkout`; the summary cards render it.
/// It is the app's estimate — the server's `charge` on the order is authoritative.
public struct PriceBreakdown: Hashable, Sendable {
    public let subtotal: Money
    public let fee: Money

    public init(subtotal: Money, fee: Money? = nil) {
        self.subtotal = subtotal
        self.fee = fee ?? .zero(subtotal.currency)
    }

    /// `quantity` items at `unitPrice` each, plus a flat fee.
    public init(unitPrice: Money, quantity: Int, fee: Money) {
        self.init(subtotal: Money(unitPrice.amount * Decimal(quantity), currency: unitPrice.currency), fee: fee)
    }

    public var total: Money {
        subtotal + fee
    }
}

/// `GET /api/v1/app-config/` — server-side switches and fees.
public struct ServerSettings: Decodable, Hashable, Sendable {
    /// Flat fee per friendly-game join, charged by the server on top of the spots.
    @LenientDecimal public var friendlyGameFee: Decimal?
    /// Flat fee per court booking, charged to the host on top of their share.
    @LenientDecimal public var bookOfCourtFee: Decimal?
    @DefaultFalse public var isCashEnable: Bool
    @DefaultFalse public var isApplePayEnable: Bool
    @DefaultFalse public var isSplitPaymentEnable: Bool
    @DefaultEmpty public var companyPhone: String
    @DefaultEmpty public var companyEmail: String
    @DefaultEmpty public var companyWhatsapp: String

    public var gameFee: Money {
        Money(friendlyGameFee ?? 0, currency: Money.defaultCurrency)
    }

    public var courtFee: Money {
        Money(bookOfCourtFee ?? 0, currency: Money.defaultCurrency)
    }
}

/// `GET /api/v1/wallet/`.
public struct Wallet: Decodable, Hashable, Sendable {
    @StrictDecimal public var balance: Decimal
    @DefaultEmpty public var currency: String

    public var money: Money {
        Money(balance, currency: currency.isEmpty ? Money.defaultCurrency : currency)
    }
}

/// `GET /api/v1/cms/pages/company_policy/` — HTML.
public struct PolicyPage: Decodable, Hashable, Sendable {
    @DefaultEmpty public var description: String
}

/// `POST /payments/split-preview/` — how the server will split wallet and card.
public struct SplitPreview: Decodable, Hashable, Sendable, Identifiable {
    public enum Outcome: String, Sendable, UnknownCaseRepresentable {
        case split
        case walletCovers = "wallet_covers"
        case disabled
        case notChosen = "not_chosen"
        case noBalance = "no_balance"
        case balanceBelowFloor = "balance_below_floor"
        case priceBelowCardFloor = "price_below_card_floor"
        case walletLegBelowFloor = "wallet_leg_below_floor"
        case unknown
    }

    @StrictDecimal public var total: Decimal
    @StrictDecimal public var fromWallet: Decimal
    @StrictDecimal public var fromCard: Decimal
    @DefaultUnknown public var outcome: Outcome
    @DefaultFalse public var isSplit: Bool

    public var id: String {
        "\(fromWallet)-\(fromCard)-\(outcome.rawValue)"
    }
}

/// `POST /payments/checkout/` and `GET /payments/{id}/`.
public struct Payment: Decodable, Hashable, Sendable, Identifiable {
    public enum Status: String, Sendable, UnknownCaseRepresentable {
        case pending, success, failed, unknown
    }

    public let id: PaymentID
    @DefaultUnknown public var status: Status
    /// Hosted SkipCash checkout page.
    @DefaultEmpty public var payUrl: String
    /// The card leg.
    @StrictDecimal public var amount: Decimal
    @LenientDecimal public var walletLegAmount: Decimal?
}

/// `POST /payments/sessions/` — an Apple Pay checkout. On the backend it is the same payment
/// record as a card checkout, so `GET /payments/{id}/` and `abandon` work with `id`.
public struct PaymentSession: Decodable, Hashable, Sendable, Identifiable {
    public let id: PaymentID
    @DefaultUnknown public var status: Payment.Status
    /// SkipCash SDK session id.
    public let sessionId: String
    /// SkipCash's page that renders the Apple Pay button and reports back with `postMessage`.
    public let checkoutUrl: String
    @StrictDecimal public var amount: Decimal
    public var expiresAt: Date?

    public func isExpired(at now: Date = .now) -> Bool {
        expiresAt.map { $0 <= now } ?? false
    }
}
