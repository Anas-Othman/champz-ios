import Foundation
import Observation

/// "TOP UP" (top_up_screen.dart): type an amount or use Quick Add, see the bonus, pay by card
/// or Apple Pay. Paying is the shared `Checkout`; a top-up has no order to create, so placing
/// it only names the amount.
@MainActor
@Observable
public final class TopUpViewModel: CheckoutOrder {
    /// Quick Add buttons; each adds to the amount (current app).
    public static let presets: [Decimal] = [100, 200, 500, 1000]

    public let checkout: Checkout
    /// What the player typed, kept to digits and up to two decimals.
    public var amountText = "" {
        didSet {
            let clean = Self.sanitize(amountText)
            if clean != amountText {
                amountText = clean
            } else {
                amountChanged()
            }
        }
    }

    /// The server's bonus quote for the current amount; nil while unknown.
    public private(set) var bonus: TopupBonus?

    private let wallet: any WalletRepository
    private let router: AppRouter
    private let toasts: ToastCenter
    private let changes: DataChanges?

    public init(
        wallet: any WalletRepository,
        payments: any PaymentRepository,
        content: any ContentRepository,
        router: AppRouter,
        toasts: ToastCenter,
        deviceSupportsApplePay: Bool = false,
        changes: DataChanges? = nil
    ) {
        self.wallet = wallet
        self.router = router
        self.toasts = toasts
        self.changes = changes
        checkout = Checkout(
            price: PriceBreakdown(subtotal: .zero(Money.defaultCurrency)),
            allowsCash: false,
            allowsWallet: false,
            deviceSupportsApplePay: deviceSupportsApplePay,
            payments: payments,
            content: content,
            toasts: toasts
        )
        checkout.order = self
    }

    /// The typed amount; nil when empty or zero.
    public var amount: Money? {
        guard let value = Decimal(string: amountText, locale: .posix), value > 0 else { return nil }
        return Money(value, currency: Money.defaultCurrency)
    }

    public func quickAdd(_ preset: Decimal) {
        let total = (amount?.amount ?? 0) + preset
        amountText = total.formatted(.number.precision(.fractionLength(0 ... 2)).grouping(.never).locale(.posix))
    }

    /// Asks the server what bonus this amount earns. Called by the view a moment after typing stops.
    public func refreshBonus() async {
        guard let amount else {
            bonus = nil
            return
        }
        let quote = try? await wallet.topupBonus(amount)
        // Typing may have moved on while this was in flight.
        if self.amount == amount {
            bonus = quote
        }
    }

    // MARK: - CheckoutOrder

    public func validateOrder() -> Bool {
        guard amount != nil else {
            toasts.show(Toast(.error, L10n.Payment.pleaseEnterValidAmount))
            return false
        }
        return true
    }

    public func placeOrder(
        _: PurchasePaymentMethod,
        idempotencyKey _: String
    ) async throws(AppError) -> PaymentPurpose {
        guard let amount else { throw .unknown }
        return .walletTopup(amount)
    }

    public func orderPaid() {
        guard let amount else { return }
        changes?.walletChanged()
        router.push(.topUpDone(TopupReceipt(amount: amount, bonus: bonus?.hasBonus == true ? bonus?.bonusMoney : nil)))
    }

    /// Apple Pay went through but is not confirmed yet: back to the wallet, which shows it once it lands.
    /// (The current app showed the success screen here.)
    public func orderProcessing() {
        changes?.walletChanged()
        router.popTo(.walletHistory)
    }

    // MARK: - Helpers

    private func amountChanged() {
        checkout.updatePrice(PriceBreakdown(subtotal: amount ?? .zero(Money.defaultCurrency)))
        if bonus?.amount != amount?.amount {
            bonus = nil
        }
    }

    /// Digits and one ".", at most two decimals; a typed "," counts as ".".
    nonisolated static func sanitize(_ text: String) -> String {
        var result = ""
        var decimals: Int?
        for character in text.replacingOccurrences(of: ",", with: ".") {
            if character == "." {
                guard decimals == nil else { continue }
                decimals = 0
                result.append(result.isEmpty ? "0." : ".")
            } else if character.isASCII, character.isNumber {
                if let count = decimals {
                    guard count < 2 else { continue }
                    decimals = count + 1
                }
                result.append(character)
            }
        }
        return String(result.prefix(9))
    }
}
