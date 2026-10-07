import Foundation
import Testing
@testable import ChampzKit

// MARK: - Fakes

actor FakePaymentRepository: PaymentRepository {
    enum Call: Equatable {
        case wallet, split(useWallet: Bool), checkout(useWallet: Bool, key: String), applePay(useWallet: Bool), status,
             abandon
    }

    private(set) var calls: [Call] = []
    /// What the last checkout or Apple Pay session was for.
    private(set) var lastPurpose: PaymentPurpose?
    var balance: Decimal = 0
    var split: SplitPreview =
        .decode(
            #"{"total": "30.00", "from_wallet": "10.00", "from_card": "20.00", "outcome": "split", "is_split": true}"#
        )
    var checkoutResult: Result<Payment, AppError> =
        .success(
            .decode(#"{"id": "pay1", "status": "pending", "pay_url": "https://pay.skipcash.app/x", "amount": "20.00"}"#)
        )
    var statuses: [Payment.Status] = [.success]

    func set(balance: Decimal) {
        self.balance = balance
    }

    func set(checkout: Result<Payment, AppError>) {
        checkoutResult = checkout
    }

    func set(statuses: [Payment.Status]) {
        self.statuses = statuses
    }

    func set(split: SplitPreview) {
        self.split = split
    }

    func wallet() async throws(AppError) -> Wallet {
        calls.append(.wallet)
        return .decode(#"{"balance": "\#(balance)", "currency": "QAR"}"#)
    }

    func splitPreview(_: PaymentPurpose, useWallet: Bool) async throws(AppError) -> SplitPreview {
        calls.append(.split(useWallet: useWallet))
        return split
    }

    func checkout(
        _ purpose: PaymentPurpose,
        useWallet: Bool,
        idempotencyKey: String
    ) async throws(AppError) -> Payment {
        lastPurpose = purpose
        calls.append(.checkout(useWallet: useWallet, key: idempotencyKey))
        return try checkoutResult.get()
    }

    func applePaySession(
        _: PaymentPurpose,
        useWallet: Bool,
        idempotencyKey _: String
    ) async throws(AppError) -> PaymentSession {
        calls.append(.applePay(useWallet: useWallet))
        return .decode(
            #"{"id": "pay1", "status": "pending", "session_id": "sdk1", "#
                + #""checkout_url": "https://sdk.skipcash.app/s/1", "amount": "20.00"}"#
        )
    }

    func payment(_: PaymentID) async throws(AppError) -> Payment {
        calls.append(.status)
        let status = statuses.isEmpty ? .pending : statuses.removeFirst()
        return .decode(#"{"id": "pay1", "status": "\#(status.rawValue)", "amount": "20.00"}"#)
    }

    func abandon(_: PaymentID) async throws(AppError) -> Payment {
        calls.append(.abandon)
        return .decode(#"{"id": "pay1", "status": "failed", "amount": "20.00"}"#)
    }
}

struct FakeContentRepository: ContentRepository {
    var settingsJSON = #"{"friendly_game_fee": "2.00", "is_cash_enable": true, "#
        + #""is_split_payment_enable": true, "is_apple_pay_enable": true}"#
    func settings() async throws(AppError) -> ServerSettings {
        .decode(settingsJSON)
    }

    func cancellationPolicy() async throws(AppError) -> String {
        "<p>24h refund</p>"
    }

    func searchPlayers(_: String) async throws(AppError) -> [FriendCandidate] {
        []
    }
}

extension Decodable {
    static func decode(_ json: String) -> Self {
        // swiftlint:disable:next force_try
        try! JSONDecoder.api().decode(Self.self, from: Data(json.utf8))
    }
}

var testBooking: BookingInfo {
    var info = BookingInfo()
    info.name = "Anas"
    info.email = "a@b.co"
    info.phone = "55551234"
    return info
}

let joined = JoinRequest.decode(
    #"{"id": "jr1", "unique_id": "Champz-000123", "payment_status": "completed", "#
        + #""amount": "30.00", "service_fee": "2.00", "charge": "32.00"}"#
)

func joinDraft(friends: Int = 0, guest: Bool = false) -> JoinDraft {
    let friendList = (0 ..< friends).map { FriendCandidate.decode(#"{"id": "f\#($0)", "full_name": "Friend \#($0)"}"#) }
    return JoinDraft(
        match: .preview, booking: testBooking,
        friends: friendList, guestEmail: guest ? "g@b.co" : nil, fee: Money(2, currency: "QAR")
    )
}

// MARK: - Confirm

@MainActor
struct JoinConfirmViewModelTests {
    private struct Harness {
        let viewModel: JoinConfirmViewModel
        let matches: FakeMatchRepository
        let payments: FakePaymentRepository
        let router: AppRouter
        let toasts: ToastCenter
    }

    private func make(balance: Decimal = 0, join: Result<JoinRequest, AppError> = .success(joined)) async -> Harness {
        let matches = FakeMatchRepository()
        await matches.set(join: join)
        let payments = FakePaymentRepository()
        await payments.set(balance: balance)
        let router = AppRouter()
        let toasts = ToastCenter()
        let viewModel = JoinConfirmViewModel(
            draft: joinDraft(),
            matches: matches,
            payments: payments,
            content: FakeContentRepository(),
            router: router,
            toasts: toasts
        )
        viewModel.checkout.pollInterval = .zero
        await viewModel.checkout.load()
        return Harness(viewModel: viewModel, matches: matches, payments: payments, router: router, toasts: toasts)
    }

    private func joinCalls(_ repo: FakeMatchRepository) async -> [PurchasePaymentMethod] {
        await repo.calls.compactMap {
            if case let .join(method, _) = $0 {
                method
            } else {
                nil
            }
        }
    }

    @Test func walletCoveringTheTotalJoinsWithWallet() async {
        let harness = await make(balance: 50)
        harness.viewModel.checkout.useWallet = true
        #expect(harness.viewModel.checkout.walletCoversAll)
        #expect(harness.viewModel.checkout.amountToPay.isZero)
        await harness.viewModel.checkout.pay()
        #expect(await joinCalls(harness.matches) == [.wallet])
        #expect(harness.router.paths[.home]?.last == .joinDone(JoinReceipt(match: .preview, joinRequest: joined)))
    }

    @Test func cashJoinsWithCash() async {
        let harness = await make()
        #expect(harness.viewModel.checkout.isCashAvailable)
        harness.viewModel.checkout.method = .cash
        await harness.viewModel.checkout.pay()
        #expect(await joinCalls(harness.matches) == [.cash])
    }

    @Test func cardJoinsOnlineThenOpensCheckoutAndFinishesWhenServerSaysPaid() async {
        let harness = await make()
        await harness.viewModel.checkout.pay()
        #expect(await joinCalls(harness.matches) == [.online])
        #expect(harness.viewModel.checkout.pendingCheckout?.id == "pay1")

        await harness.viewModel.checkout
            .checkoutFinished(callback: URL(string: "champz://payment/callback?status=paid"))
        #expect(harness.viewModel.checkout.pendingCheckout == nil)
        #expect(harness.router.paths[.home]?.last == .joinDone(JoinReceipt(match: .preview, joinRequest: joined)))
    }

    @Test func redirectIsNotTrustedOverTheServer() async {
        let harness = await make()
        await harness.payments.set(statuses: [.failed])
        await harness.viewModel.checkout.pay()
        await harness.viewModel.checkout
            .checkoutFinished(callback: URL(string: "champz://payment/callback?status=paid"))
        #expect(harness.router.paths[.home, default: []].isEmpty)
        #expect(await harness.payments.calls.contains(.abandon))
        #expect(harness.toasts.current?.kind == .error)
    }

    @Test func closingThePageWhilePendingAbandonsAndStartsFreshNextTime() async {
        let harness = await make()
        await harness.payments.set(statuses: [.pending, .pending])
        await harness.viewModel.checkout.pay()
        await harness.viewModel.checkout.checkoutFinished(callback: nil)
        #expect(await harness.payments.calls.contains(.abandon))
        #expect(harness.toasts.current?.kind == .info)

        await harness.viewModel.checkout.pay()
        let keys = await harness.matches.calls.compactMap {
            if case let .join(_, key) = $0 {
                key
            } else {
                nil
            }
        }
        #expect(keys.count == 2)
        #expect(keys[0] != keys[1]) // the abandoned join was released; a new one gets a new key
    }

    @Test func retryAfterCheckoutErrorReusesTheSameJoinAndKey() async {
        let harness = await make()
        await harness.payments.set(checkout: .failure(.offline))
        await harness.viewModel.checkout.pay()
        await harness.viewModel.checkout.pay()
        #expect(await joinCalls(harness.matches) == [.online]) // one join, not two
        let checkoutKeys = await harness.payments.calls
            .compactMap {
                if case let .checkout(_, key) = $0 {
                    key
                } else {
                    nil
                }
            }
        #expect(checkoutKeys.count == 2)
        #expect(checkoutKeys[0] == checkoutKeys[1])
    }

    @Test func partialWalletAsksTheServerForTheSplitBeforePaying() async {
        let harness = await make(balance: 10)
        harness.viewModel.checkout.useWallet = true
        #expect(harness.viewModel.checkout.isSplit)
        await harness.viewModel.checkout.pay()
        #expect(harness.viewModel.checkout.splitToConfirm?.fromCard == 20)
        #expect(await harness.payments.calls.contains(.split(useWallet: true)))
        #expect(harness.viewModel.checkout.pendingCheckout == nil) // nothing charged until the player accepts

        await harness.viewModel.checkout.payOnline(useWallet: true)
        #expect(await harness.payments.calls
            .contains {
                if case .checkout(useWallet: true, _) = $0 {
                    true
                } else {
                    false
                }
            })
        #expect(harness.viewModel.checkout.pendingCheckout != nil)
    }

    @Test func insufficientFundsShowsASentenceAndRefreshesTheWallet() async {
        let harness = await make(balance: 50, join: .failure(.payment(.insufficientFunds)))
        harness.viewModel.checkout.useWallet = true
        await harness.viewModel.checkout.pay()
        #expect(harness.toasts.current?.kind == .error)
        #expect(await harness.payments.calls.filter { $0 == .wallet }.count == 2)
    }
}
