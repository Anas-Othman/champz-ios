import Foundation

public extension Checkout {
    /// For purchases whose amount the player types (top-up). A new amount is a new attempt:
    /// the old order, keys and any Apple Pay button for the old amount are dropped.
    func updatePrice(_ newPrice: PriceBreakdown) {
        guard newPrice != price, !isSubmitting else { return }
        price = newPrice
        placed = nil
        orderKey = UUID().uuidString
        checkoutKey = UUID().uuidString
        if applePaySession != nil {
            Task { await cancelApplePay() }
        }
    }
}
