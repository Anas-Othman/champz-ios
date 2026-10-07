import Foundation

/// What a paid flow (join a match, book a court, join a tournament…) gives `Checkout`.
@MainActor
public protocol CheckoutOrder: AnyObject {
    /// Records the purchase with the chosen method and returns what the payment endpoints should charge.
    /// Called at most once per attempt; `idempotencyKey` stays the same when the same attempt is retried.
    func placeOrder(_ method: PurchasePaymentMethod, idempotencyKey: String) async throws(AppError) -> PaymentPurpose
    /// The purchase is paid (wallet/cash at once, card or Apple Pay once the server confirms).
    func orderPaid()
    /// The wallet sheet succeeded but the server has not confirmed yet. Leave the screen
    /// without abandoning: the webhook will settle it and the player is notified.
    func orderProcessing()
    /// Checks the screen's own fields before anything is sent; false stops the payment.
    func validateOrder() -> Bool
}

public extension CheckoutOrder {
    func validateOrder() -> Bool {
        true
    }
}
