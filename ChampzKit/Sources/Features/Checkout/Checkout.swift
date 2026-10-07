import Foundation
import Observation

/// Everything about paying, shared by every paid flow: payment method, "use my balance",
/// the server's split, the hosted card page, Apple Pay, verification and abandon.
///
/// Money rules (guide §9):
/// - one order per attempt, reused on retry, with an `Idempotency-Key`;
/// - the server decides any wallet/card split (`split-preview`), the app only shows it;
/// - a card or Apple Pay payment is confirmed by asking the server, never by trusting the page.
@MainActor
@Observable
public final class Checkout {
    public enum Method: Hashable, Sendable { case card, cash, applePay }

    public struct Context: Sendable {
        public let settings: ServerSettings
        public let wallet: Wallet
        public let policy: String
    }

    /// What the purchase costs (the app's estimate; the server's charge is authoritative).
    public internal(set) var price: PriceBreakdown
    public var total: Money {
        price.total
    }

    public weak var order: (any CheckoutOrder)?

    public private(set) var state: Loadable<Context> = .idle
    public var method: Method? = .card {
        didSet {
            if oldValue == .applePay, method != .applePay {
                Task { await cancelApplePay() }
            }
        }
    }

    public var useWallet = false
    public internal(set) var isSubmitting = false
    /// Set when the server proposes a split; the view shows it for confirmation.
    public var splitToConfirm: SplitPreview?
    /// Set when a hosted card page must be shown; the view opens it and reports back.
    public internal(set) var pendingCheckout: Payment?
    /// Set when the Apple Pay button (SkipCash's page) must replace the pay button.
    public internal(set) var applePaySession: PaymentSession?
    /// Apple Pay went through but the server has not confirmed it yet.
    public var isProcessingNoticePresented = false

    /// Gap between payment status checks; tests set it to zero.
    var pollInterval: Duration = .seconds(2)
    /// Whether this device can show the Apple Pay sheet; the app sets it from PassKit.
    let deviceSupportsApplePay: Bool

    private let allowsCash: Bool
    /// False for a wallet top-up: you cannot pay into your wallet from your wallet.
    public let allowsWallet: Bool
    var placed: (method: PurchasePaymentMethod, purpose: PaymentPurpose)?
    var orderKey = UUID().uuidString
    var checkoutKey = UUID().uuidString

    let payments: any PaymentRepository
    private let content: any ContentRepository
    let toasts: ToastCenter

    /// - Parameters:
    ///   - allowsCash: whether this kind of purchase can be paid in cash at all (the server switch must also be on).
    ///   - allowsWallet: whether "use my balance" is offered.
    ///   - deviceSupportsApplePay: `PKPaymentAuthorizationController.canMakePayments()` in the app.
    public init(
        price: PriceBreakdown,
        allowsCash: Bool,
        allowsWallet: Bool = true,
        deviceSupportsApplePay: Bool = false,
        payments: any PaymentRepository,
        content: any ContentRepository,
        toasts: ToastCenter
    ) {
        self.price = price
        self.allowsCash = allowsCash
        self.allowsWallet = allowsWallet
        self.deviceSupportsApplePay = deviceSupportsApplePay
        self.payments = payments
        self.content = content
        self.toasts = toasts
    }

    public func load() async {
        guard case .idle = state else { return }
        state = .loading
        do {
            async let settings = content.settings()
            async let wallet = payments.wallet()
            let (serverSettings, balance) = try await (settings, wallet)
            let policy = await (try? content.cancellationPolicy()) ?? ""
            state = .loaded(Context(settings: serverSettings, wallet: balance, policy: policy))
            if method == .cash, !isCashAvailable {
                method = .card
            }
            if method == .applePay, !isApplePayAvailable {
                method = .card
            }
        } catch let error as AppError {
            state = .failed(error)
        } catch {
            state = .failed(.unknown)
        }
    }

    // MARK: - What the screen shows

    public var balance: Money {
        state.value?.wallet.money ?? .zero(Money.defaultCurrency)
    }

    public var policy: String {
        state.value?.policy ?? ""
    }

    public var isCashAvailable: Bool {
        allowsCash && (state.value?.settings.isCashEnable ?? false)
    }

    /// Server switch (`is_apple_pay_enable`) and a device that can pay.
    public var isApplePayAvailable: Bool {
        deviceSupportsApplePay && (state.value?.settings.isApplePayEnable ?? false)
    }

    /// Wallet can be used if it covers everything, or covers part and the server allows splits.
    public var canUseWallet: Bool {
        guard allowsWallet, let context = state.value, !balance.isZero else { return false }
        return balance.amount >= total.amount || context.settings.isSplitPaymentEnable
    }

    public var walletCoversAll: Bool {
        useWallet && canUseWallet && balance.amount >= total.amount
    }

    public var isSplit: Bool {
        useWallet && canUseWallet && !walletCoversAll
    }

    /// What the pay button shows: nothing left to pay when the wallet covers it.
    public var amountToPay: Money {
        guard useWallet, canUseWallet else { return total }
        return walletCoversAll ? .zero(total.currency) : total - balance
    }

    /// No card or Apple Pay involved: the purchase completes in one call.
    public var completesImmediately: Bool {
        walletCoversAll || (method == .cash && !useWallet)
    }

    // MARK: - Pay

    public func pay() async {
        guard !isSubmitting, order?.validateOrder() ?? true else { return }
        if !walletCoversAll, method == nil {
            toasts.show(Toast(.error, L10n.Payment.pleaseSelectPaymentMethod))
            return
        }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            if walletCoversAll {
                _ = try await place(.wallet)
                order?.orderPaid()
            } else if method == .cash, !useWallet {
                _ = try await place(.cash)
                order?.orderPaid()
            } else {
                let purpose = try await place(.online)
                if useWallet {
                    let preview = try await payments.splitPreview(purpose, useWallet: true)
                    if preview.outcome == .walletCovers {
                        toasts.show(Toast(.info, L10n.Join.walletCovers))
                        await refreshWallet()
                        return
                    }
                    splitToConfirm = preview // the view asks the player, then calls `payOnline`
                } else {
                    try await startOnline(purpose, useWallet: false)
                }
            }
        } catch {
            await handle(error)
        }
    }

    /// The player accepted the split shown in the sheet: open the card page or the Apple Pay button.
    public func payOnline(useWallet: Bool) async {
        splitToConfirm = nil
        guard let purpose = placed?.purpose else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await startOnline(purpose, useWallet: useWallet)
        } catch {
            await handle(error)
        }
    }

    /// The hosted page closed. `callback` is `champz://payment/callback?…` when SkipCash redirected,
    /// nil when the player closed it. Either way the server has the final word.
    public func checkoutFinished(callback: URL?) async {
        guard let payment = pendingCheckout else { return }
        pendingCheckout = nil
        isSubmitting = true
        defer { isSubmitting = false }
        let redirectedPaid = callback.flatMap(DeepLinkParser.parse) == .paymentCallback(.paid)
        // Redirected: give the webhook up to ~30 s. Closed by hand: check twice, 2 s apart (current app).
        switch await pollStatus(payment.id, attempts: redirectedPaid ? 15 : 2) {
        case .success:
            order?.orderPaid()
        case .failed:
            await abandon(payment.id, toast: Toast(.error, L10n.Payment.paymentFailed))
        case .pending, .unknown:
            await abandon(payment.id, toast: Toast(.info, L10n.Payment.paymentCancelled))
        }
        await refreshWallet()
    }

    // MARK: - Steps

    /// One order per attempt. A retry with the same method reuses it; the idempotency key protects
    /// against a double submit reaching the server twice.
    func place(_ method: PurchasePaymentMethod) async throws(AppError) -> PaymentPurpose {
        if let placed, placed.method == method {
            return placed.purpose
        }
        guard let order else { throw .unknown }
        let purpose = try await order.placeOrder(method, idempotencyKey: orderKey)
        placed = (method, purpose)
        return purpose
    }

    private func startOnline(_ purpose: PaymentPurpose, useWallet: Bool) async throws(AppError) {
        if method == .applePay {
            applePaySession = try await payments.applePaySession(
                purpose,
                useWallet: useWallet,
                idempotencyKey: checkoutKey
            )
        } else {
            let payment = try await payments.checkout(purpose, useWallet: useWallet, idempotencyKey: checkoutKey)
            guard URL(string: payment.payUrl) != nil else { throw .unknown }
            pendingCheckout = payment
        }
    }

    func pollStatus(_ id: PaymentID, attempts: Int) async -> Payment.Status {
        for attempt in 0 ..< attempts {
            if let payment = try? await payments.payment(id), payment.status != .pending {
                return payment.status
            }
            if attempt < attempts - 1 {
                try? await Task.sleep(for: pollInterval)
            }
        }
        return .pending
    }

    /// Refunds any wallet leg and releases the pending order; the next attempt starts fresh.
    func abandon(_ id: PaymentID, toast: Toast?) async {
        _ = try? await payments.abandon(id)
        placed = nil
        orderKey = UUID().uuidString
        checkoutKey = UUID().uuidString
        if let toast {
            toasts.show(toast)
        }
    }

    func handle(_ error: AppError) async {
        if error.apiCode == APIErrorCode.walletCoversPurchase {
            toasts.show(Toast(.info, L10n.Join.walletCovers))
        } else {
            toasts.show(error)
        }
        if case .payment(.insufficientFunds) = error {
            await refreshWallet()
        }
    }

    func refreshWallet() async {
        guard let context = state.value, let wallet = try? await payments.wallet() else { return }
        state = .loaded(Context(settings: context.settings, wallet: wallet, policy: context.policy))
    }
}
