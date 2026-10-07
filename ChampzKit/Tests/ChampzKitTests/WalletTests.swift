import Foundation
import Testing
@testable import ChampzKit

/// Scripted `WalletRepository`: pages served by cursor ("" → first, "1" → second…).
actor FakeWalletRepository: WalletRepository {
    private(set) var cursors: [String?] = []
    var pages: [CursorPage<LedgerEntry>] = []
    var bonusPercent: Decimal = 0

    func set(pages: [CursorPage<LedgerEntry>]) {
        self.pages = pages
    }

    func set(bonusPercent: Decimal) {
        self.bonusPercent = bonusPercent
    }

    func transactions(cursor: String?) async throws(AppError) -> CursorPage<LedgerEntry> {
        cursors.append(cursor)
        let index = cursor.flatMap(Int.init) ?? 0
        guard index < pages.count else { throw .notFound }
        return pages[index]
    }

    func topupBonus(_ amount: Money) async throws(AppError) -> TopupBonus {
        let bonus = amount.amount * bonusPercent / 100
        return .decode(
            #"{"amount": "\#(amount.apiString)", "bonus": "\#(Money(bonus, currency: "QAR").apiString)", "#
                + #""total": "\#(Money(amount.amount + bonus, currency: "QAR").apiString)", "#
                + #""percentage": "\#(bonusPercent)", "enabled": \#(bonusPercent > 0), "currency": "QAR"}"#
        )
    }
}

private func ledgerPage(_ ids: [String], next: String?) -> CursorPage<LedgerEntry> {
    let items = ids.map { #"{"id": "\#($0)", "amount": "-10.00", "currency": "QAR", "reason": "match_fee", "#
        + #""created_at": "2026-10-07T12:45:00Z"}"#
    }.joined(separator: ",")
    return .decode(#"{"items": [\#(items)], "next_cursor": \#(next.map { "\"\($0)\"" } ?? "null")}"#)
}

struct WalletModelTests {
    @Test func ledgerEntriesReadSignAndReason() {
        let credit = LedgerEntry.decode(#"{"id": "l1", "amount": "50.00", "currency": "QAR", "reason": "topup"}"#)
        let debit = LedgerEntry.decode(#"{"id": "l2", "amount": "-175.50", "currency": "QAR", "reason": "new_thing"}"#)
        #expect(credit.isCredit && credit.signedText == "+ 50 QR")
        #expect(!debit.isCredit && debit.signedText == "- 175.5 QR")
        #expect(debit.reason == .unknown) // a new server code does not break the list
    }

    @Test func topupPurposeSendsTheAmountAsATwoPlaceString() throws {
        #expect(PaymentPurpose.walletTopup(Money(1000, currency: "QAR")).body
            == ["purpose": "wallet_topup", "amount": "1000.00"])
        #expect(try WalletAPI.topupBonus(Money(#require(Decimal(string: "12.5")), currency: "QAR")).query
            == [URLQueryItem(name: "amount", value: "12.50")])
    }

    @Test func amountInputKeepsDigitsAndTwoDecimals() {
        #expect(TopUpViewModel.sanitize("1,5") == "1.5")
        #expect(TopUpViewModel.sanitize("12.345") == "12.34")
        #expect(TopUpViewModel.sanitize("a1b2") == "12")
        #expect(TopUpViewModel.sanitize(".5") == "0.5")
        #expect(TopUpViewModel.sanitize("1.2.3") == "1.23")
    }
}

@MainActor
struct WalletViewModelTests {
    @Test func loadsBalanceAndPagesWithTheCursor() async {
        let wallet = FakeWalletRepository()
        await wallet.set(pages: [ledgerPage(["a", "b"], next: "1"), ledgerPage(["c"], next: nil)])
        let payments = FakePaymentRepository()
        await payments.set(balance: 95)
        let viewModel = WalletViewModel(wallet: wallet, payments: payments, router: AppRouter(), toasts: ToastCenter())

        await viewModel.load()
        #expect(viewModel.state.value?.balance.amount == 95)
        let entries = viewModel.state.value?.entries ?? []
        await viewModel.loadMoreIfNeeded(after: entries[0]) // not the last row: nothing
        await viewModel.loadMoreIfNeeded(after: entries[1])
        #expect(viewModel.state.value?.entries.map(\.id) == ["a", "b", "c"])
        #expect(await wallet.cursors == [nil, "1"])
    }

    @Test func topUpOpensTheTopUpScreen() {
        let router = AppRouter()
        WalletViewModel(
            wallet: FakeWalletRepository(),
            payments: FakePaymentRepository(),
            router: router,
            toasts: ToastCenter()
        )
        .topUp()
        #expect(router.paths[.home]?.last == .topUp)
    }
}

@MainActor
struct TopUpViewModelTests {
    private struct Harness {
        let viewModel: TopUpViewModel
        let wallet: FakeWalletRepository
        let payments: FakePaymentRepository
        let router: AppRouter
        let changes: DataChanges
    }

    private func make(balance: Decimal = 500) async -> Harness {
        let wallet = FakeWalletRepository()
        let payments = FakePaymentRepository()
        await payments.set(balance: balance)
        let router = AppRouter()
        let changes = DataChanges()
        let viewModel = TopUpViewModel(
            wallet: wallet, payments: payments, content: FakeContentRepository(),
            router: router, toasts: ToastCenter(), changes: changes
        )
        await viewModel.checkout.load()
        viewModel.checkout.pollInterval = .zero
        return Harness(viewModel: viewModel, wallet: wallet, payments: payments, router: router, changes: changes)
    }

    @Test func walletIsNeverOfferedForATopUp() async {
        let harness = await make(balance: 500)
        harness.viewModel.amountText = "50"
        harness.viewModel.checkout.useWallet = true
        #expect(harness.viewModel.checkout.canUseWallet == false)
        #expect(harness.viewModel.checkout.amountToPay.amount == 50)
        #expect(harness.viewModel.checkout.isCashAvailable == false)
    }

    @Test func quickAddAddsToTheAmount() async {
        let harness = await make()
        harness.viewModel.amountText = "50"
        harness.viewModel.quickAdd(100)
        harness.viewModel.quickAdd(200)
        #expect(harness.viewModel.amountText == "350")
        #expect(harness.viewModel.checkout.total.amount == 350)
    }

    @Test func noAmountNoPayment() async {
        let harness = await make()
        await harness.viewModel.checkout.pay()
        #expect(await harness.payments.lastPurpose == nil)
    }

    @Test func cardTopUpPaysTheTypedAmountAndShowsTheTicket() async {
        let harness = await make()
        await harness.wallet.set(bonusPercent: 10)
        harness.viewModel.amountText = "100"
        await harness.viewModel.refreshBonus()
        #expect(harness.viewModel.bonus?.bonusMoney.amount == 10)

        await harness.viewModel.checkout.pay()
        #expect(await harness.payments.lastPurpose == .walletTopup(Money(100, currency: "QAR")))
        await harness.viewModel.checkout
            .checkoutFinished(callback: URL(string: "champz://payment/callback?status=paid"))

        let receipt = TopupReceipt(amount: Money(100, currency: "QAR"), bonus: Money(10, currency: "QAR"))
        #expect(harness.router.paths[.home]?.last == .topUpDone(receipt))
        #expect(harness.changes.walletVersion == 1)
    }

    @Test func changingTheAmountStartsAFreshAttempt() async {
        let harness = await make()
        harness.viewModel.amountText = "100"
        await harness.payments.set(checkout: .failure(.offline))
        await harness.viewModel.checkout.pay()
        let firstKeys = await harness.payments.calls
            .compactMap {
                if case let .checkout(_, key) = $0 {
                    key
                } else {
                    nil
                }
            }

        harness.viewModel.amountText = "150"
        await harness.viewModel.checkout.pay()
        let keys = await harness.payments.calls.compactMap {
            if case let .checkout(_, key) = $0 {
                key
            } else {
                nil
            }
        }
        #expect(await harness.payments.lastPurpose == .walletTopup(Money(150, currency: "QAR")))
        #expect(keys.count == 2 && keys[1] != firstKeys[0]) // not the old amount's key
    }
}
