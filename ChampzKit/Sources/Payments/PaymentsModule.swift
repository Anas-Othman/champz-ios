import Domain
import Foundation

/// The checkout engine (guide, section 9) lands here in the first vertical slice:
/// `CheckoutViewModel`, `PurposeHandler`, `SplitPreviewService`, `CardCheckoutPresenter`,
/// `ApplePayPresenter`, `PaymentVerifier`, `CheckoutResultView`.
///
/// Polling cadence copied from the current app (PAYMENT_FEATURE_DOCS_V2.md):
public enum PaymentsPolicy {
    /// Card: poll `GET /payments/{id}/` every 3 s for up to 5 min.
    public static let cardPollInterval: Duration = .seconds(3)
    public static let cardPollTimeout: Duration = .seconds(300)
    /// Browser closed without a callback: check twice, 2 s apart, before treating as cancelled.
    public static let cardCloseRecheckInterval: Duration = .seconds(2)
    public static let cardCloseRecheckCount = 2
    /// Apple Pay: verify `GET /payments/sessions/{id}/` every 2 s, up to 10 times.
    public static let applePayPollInterval: Duration = .seconds(2)
    public static let applePayPollAttempts = 10
}
