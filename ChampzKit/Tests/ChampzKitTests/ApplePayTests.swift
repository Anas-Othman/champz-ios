import Foundation
import Testing
@testable import ChampzKit

@MainActor
private final class Order: CheckoutOrder {
    var placedCount = 0
    var paid = 0
    var processing = 0

    func placeOrder(_: PurchasePaymentMethod, idempotencyKey _: String) async throws(AppError) -> PaymentPurpose {
        placedCount += 1
        return .friendlyGameJoin("order-1")
    }

    func orderPaid() {
        paid += 1
    }

    func orderProcessing() {
        processing += 1
    }
}

@MainActor
struct ApplePayTests {
    private struct Harness {
        let checkout: Checkout
        let order: Order
        let payments: FakePaymentRepository
    }

    private func make(device: Bool = true, statuses: [Payment.Status] = [.success]) async -> Harness {
        let payments = FakePaymentRepository()
        await payments.set(statuses: statuses)
        let checkout = Checkout(
            price: PriceBreakdown(subtotal: Money(30, currency: "QAR")),
            allowsCash: true,
            deviceSupportsApplePay: device,
            payments: payments,
            content: FakeContentRepository(),
            toasts: ToastCenter()
        )
        let order = Order()
        checkout.order = order
        checkout.pollInterval = .zero
        await checkout.load()
        checkout.method = .applePay
        return Harness(checkout: checkout, order: order, payments: payments)
    }

    @Test func offeredOnlyWhenServerAndDeviceAllow() async {
        #expect(await make(device: true).checkout.isApplePayAvailable)
        #expect(await !make(device: false).checkout.isApplePayAvailable)
    }

    @Test func payCreatesASessionInsteadOfACardPage() async {
        let harness = await make()
        await harness.checkout.pay()
        #expect(harness.checkout.applePaySession?.checkoutUrl == "https://sdk.skipcash.app/s/1")
        #expect(harness.checkout.pendingCheckout == nil)
        #expect(await harness.payments.calls.contains(.applePay(useWallet: false)))
    }

    @Test func paidAndConfirmedByTheServerCompletesTheOrder() async {
        let harness = await make(statuses: [.success])
        await harness.checkout.pay()
        await harness.checkout.applePayReported(.paid(orderId: "pay1"))
        #expect(harness.order.paid == 1)
        #expect(harness.checkout.applePaySession == nil)
    }

    @Test func paidButUnconfirmedShowsProcessingAndNeverAbandons() async {
        let harness = await make(statuses: Array(repeating: .pending, count: 15))
        await harness.checkout.pay()
        await harness.checkout.applePayReported(.paid(orderId: "pay1"))
        #expect(harness.checkout.isProcessingNoticePresented)
        #expect(harness.order.paid == 0)
        #expect(await !harness.payments.calls.contains(.abandon)) // the money may already be taken
        harness.checkout.processingAcknowledged()
        #expect(harness.order.processing == 1)
    }

    @Test func failedSheetAbandonsAndStartsFresh() async {
        let harness = await make()
        await harness.checkout.pay()
        await harness.checkout.applePayReported(.failed)
        #expect(await harness.payments.calls.contains(.abandon))
        await harness.checkout.pay()
        #expect(harness.order.placedCount == 2) // the abandoned order was released
    }

    @Test func pageErrorKeepsTheOrderAndAsksForANewSession() async {
        let harness = await make()
        await harness.checkout.pay()
        await harness.checkout.applePayReported(.error)
        #expect(harness.checkout.applePaySession == nil)
        #expect(await !harness.payments.calls.contains(.abandon))
        await harness.checkout.pay()
        #expect(harness.order.placedCount == 1) // same order, new session
        #expect(harness.checkout.applePaySession != nil)
    }

    @Test func leavingWithALiveSessionReleasesIt() async {
        let harness = await make()
        await harness.checkout.pay()
        await harness.checkout.cancelApplePay()
        #expect(harness.checkout.applePaySession == nil)
        #expect(await harness.payments.calls.contains(.abandon))
    }

    @Test func bridgeMessagesParseLikeTheCurrentApp() {
        #expect(ApplePayMessage.parse(#"{"status":"paid","orderId":"abc"}"#) == .paid(orderId: "abc"))
        #expect(ApplePayMessage.parse(["status": "paid", "orderId": 42]) == .paid(orderId: "42"))
        #expect(ApplePayMessage.parse(#"{"status":"paid"}"#) == nil) // no orderId: ignored
        #expect(ApplePayMessage.parse(#"{"status":"failed"}"#) == .failed)
        #expect(ApplePayMessage.parse(#"{"status":"error"}"#) == .error)
        #expect(ApplePayMessage.parse(#"{"type":"skipcash-fullscreen","status":"paid","orderId":"x"}"#) == nil)
        #expect(ApplePayMessage.parse("not json") == nil)
    }

    @Test func sessionDecodesAndKnowsWhenItExpired() throws {
        let json = #"{"id": "pay1", "session_id": "s1", "checkout_url": "https://x", "amount": "20.00", "#
            + #""expires_at": "2026-10-06T10:00:00Z"}"#
        let session = try JSONDecoder.api().decode(PaymentSession.self, from: Data(json.utf8))
        let expiry = try #require(session.expiresAt)
        #expect(!session.isExpired(at: expiry.addingTimeInterval(-1)))
        #expect(session.isExpired(at: expiry))
        #expect(throws: DecodingError.self) { // no checkout page: unusable
            try JSONDecoder.api().decode(
                PaymentSession.self,
                from: Data(#"{"id": "p", "session_id": "s", "amount": "1"}"#.utf8)
            )
        }
    }
}
