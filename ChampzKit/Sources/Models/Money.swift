import Foundation

/// An amount in a currency. Always `Decimal`, never `Double` (lint rule `no_double_money`).
/// The currency comes from the server; nothing in the app assumes QAR.
public struct Money: Hashable, Sendable, Comparable, CustomStringConvertible {
    public let amount: Decimal
    /// ISO 4217 code, e.g. "QAR".
    public let currency: String

    public init(_ amount: Decimal, currency: String) {
        self.amount = amount
        self.currency = currency
    }

    public static func zero(_ currency: String) -> Money {
        Money(0, currency: currency)
    }

    public var isZero: Bool {
        amount == 0
    }

    /// Localised, e.g. "QAR 30.00" or "٣٠٫٠٠ ر.ق" depending on the user's locale.
    public func formatted(locale: Locale = .current) -> String {
        amount.formatted(.currency(code: currency).locale(locale).precision(.fractionLength(2)))
    }

    public var description: String {
        "\(amount) \(currency)"
    }

    public static func + (lhs: Money, rhs: Money) -> Money {
        precondition(lhs.currency == rhs.currency, "Cannot add \(lhs.currency) to \(rhs.currency)")
        return Money(lhs.amount + rhs.amount, currency: lhs.currency)
    }

    public static func - (lhs: Money, rhs: Money) -> Money {
        precondition(lhs.currency == rhs.currency, "Cannot subtract \(rhs.currency) from \(lhs.currency)")
        return Money(lhs.amount - rhs.amount, currency: lhs.currency)
    }

    public static func < (lhs: Money, rhs: Money) -> Bool {
        precondition(lhs.currency == rhs.currency, "Cannot compare \(lhs.currency) with \(rhs.currency)")
        return lhs.amount < rhs.amount
    }
}

public extension Money {
    /// Until venues carry a currency (countries table), amounts without one are QAR.
    static let defaultCurrency = "QAR"

    /// "50.00": the decimal string the API takes for an amount.
    var apiString: String {
        amount.formatted(.number.precision(.fractionLength(2)).grouping(.never).locale(.posix))
    }

    /// "30 QR" / "24.99 QR" — the current app's compact style (`AppConstant.currency`).
    var compact: String {
        let number = amount.formatted(.number.precision(.fractionLength(0 ... 2)).locale(.posix))
        return "\(number) \(currencyLabel)"
    }

    /// Short label shown next to amounts. Qatar riyal reads "QR" in the app.
    var currencyLabel: String {
        currency == "QAR" ? "QR" : currency
    }
}
