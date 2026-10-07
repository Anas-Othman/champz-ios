import Foundation
import Testing
@testable import ChampzKit

/// A stand-in purchase (think: court booking) to show `Checkout` knows nothing about matches.
@MainActor
private final class RecordingOrder: CheckoutOrder {
    var placed: [(PurchasePaymentMethod, String)] = []
    var paid = 0

    func placeOrder(_ method: PurchasePaymentMethod, idempotencyKey: String) async throws(AppError) -> PaymentPurpose {
        placed.append((method, idempotencyKey))
        return .friendlyGameJoin("order-1")
    }

    func orderPaid() {
        paid += 1
    }

    var processing = 0
    func orderProcessing() {
        processing += 1
    }
}

@MainActor
struct CheckoutTests {
    private struct Harness {
        let checkout: Checkout
        let order: RecordingOrder
    }

    private func make(
        total: Decimal,
        balance: Decimal,
        allowsCash: Bool = true
    ) async -> Harness {
        let payments = FakePaymentRepository()
        await payments.set(balance: balance)
        let checkout = Checkout(
            price: PriceBreakdown(subtotal: Money(total, currency: "QAR")),
            allowsCash: allowsCash,
            payments: payments,
            content: FakeContentRepository(),
            toasts: ToastCenter()
        )
        let order = RecordingOrder()
        checkout.order = order
        checkout.pollInterval = .zero
        await checkout.load()
        return Harness(checkout: checkout, order: order)
    }

    @Test func walletPaysAnyOrder() async {
        let harness = await make(total: 40, balance: 100)
        let (checkout, order) = (harness.checkout, harness.order)
        checkout.useWallet = true
        await checkout.pay()
        #expect(order.placed.map(\.0) == [.wallet])
        #expect(order.paid == 1)
    }

    @Test func cashIsHiddenWhenThePurchaseDoesNotAllowIt() async {
        let harness = await make(total: 40, balance: 0, allowsCash: false)
        #expect(!harness.checkout.isCashAvailable)
    }

    @Test func cardPaysOnlyAfterTheServerConfirms() async {
        let harness = await make(total: 40, balance: 0)
        let (checkout, order) = (harness.checkout, harness.order)
        await checkout.pay()
        #expect(order.paid == 0)
        #expect(checkout.pendingCheckout != nil)
        await checkout.checkoutFinished(callback: nil)
        #expect(order.paid == 1) // fake server says success on the first status check
    }

    @Test func amountsFollowTheWalletChoice() async {
        let harness = await make(total: 40, balance: 15)
        let checkout = harness.checkout
        #expect(checkout.amountToPay == Money(40, currency: "QAR"))
        checkout.useWallet = true
        #expect(checkout.isSplit)
        #expect(checkout.amountToPay == Money(25, currency: "QAR"))
        #expect(!checkout.completesImmediately)
    }

    @Test func summaryRowsFollowFeeAndWallet() async {
        let payments = FakePaymentRepository()
        await payments.set(balance: 100)
        let checkout = Checkout(
            price: PriceBreakdown(subtotal: Money(30, currency: "QAR"), fee: Money(2, currency: "QAR")),
            allowsCash: true,
            payments: payments,
            content: FakeContentRepository(),
            toasts: ToastCenter()
        )
        await checkout.load()
        let card = CheckoutSummaryCard(checkout: checkout)
        #expect(card.rows.map(\.value) == ["30 QR", "2 QR"])
        checkout.useWallet = true
        #expect(card.rows.map(\.value) == ["30 QR", "2 QR", "- 32 QR"])

        let noFee = OrderSummaryCard(price: PriceBreakdown(subtotal: Money(30, currency: "QAR")))
        #expect(noFee.rows.count == 1)
        let registration = OrderSummaryCard(
            price: PriceBreakdown(subtotal: Money(30, currency: "QAR")),
            showsZeroFee: true
        )
        #expect(registration.rows.map(\.value) == ["30 QR", "0 QR"])
    }
}
