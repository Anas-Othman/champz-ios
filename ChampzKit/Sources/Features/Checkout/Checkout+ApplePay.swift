import Foundation

/// What SkipCash's Apple Pay page reports through `postMessage` (apple_pay_button.dart).
public enum ApplePayMessage: Equatable, Sendable {
    /// The sheet completed; the server still has to confirm.
    case paid(orderId: String)
    case failed
    /// The page itself broke (session problem); a new session usually fixes it.
    case error

    /// Parses one message body: a JSON string or an object, e.g. `{"status":"paid","orderId":"…"}`.
    /// `skipcash-fullscreen` and anything unknown are ignored.
    public static func parse(_ body: Any) -> ApplePayMessage? {
        let object: [String: Any]? = if let text = body as? String, let data = text.data(using: .utf8) {
            try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        } else {
            body as? [String: Any]
        }
        guard let object, object["type"] as? String != "skipcash-fullscreen" else { return nil }
        switch object["status"] as? String {
        case "paid":
            guard let orderId = object["orderId"].map({ "\($0)" }), !orderId.isEmpty else { return nil }
            return .paid(orderId: orderId)
        case "failed": return .failed
        case "error": return .error
        default: return nil
        }
    }
}

public extension Checkout {
    /// SkipCash's Apple Pay page reported a result.
    func applePayReported(_ message: ApplePayMessage) async {
        guard let session = applePaySession else { return }
        switch message {
        case .paid:
            applePaySession = nil
            isSubmitting = true
            defer { isSubmitting = false }
            // The sheet says paid; the webhook makes it true. Up to ~30 s, then tell the player it is processing.
            switch await pollStatus(session.id, attempts: 15) {
            case .success:
                order?.orderPaid()
            case .failed:
                await abandon(session.id, toast: Toast(.error, L10n.Payment.paymentFailed))
            case .pending, .unknown:
                // Never abandon here: the money may already be taken.
                isProcessingNoticePresented = true
            }
        case .failed:
            applePaySession = nil
            await abandon(session.id, toast: Toast(.error, L10n.Payment.paymentFailed))
            await refreshWallet()
        case .error:
            // Keep the order; the next tap asks the server for a session again (it reuses a live one).
            applePaySession = nil
            toasts.show(Toast(.error, L10n.Checkout.applePayUnavailable))
        }
    }

    /// The session ran out before the player paid: drop it, the pay button creates a new one.
    func applePayExpired() {
        applePaySession = nil
    }

    /// The player acknowledged "Payment processing".
    func processingAcknowledged() {
        isProcessingNoticePresented = false
        order?.orderProcessing()
    }

    /// Leaving Apple Pay (another method, or the screen) with an unpaid session: release it.
    func cancelApplePay() async {
        guard let session = applePaySession else { return }
        applePaySession = nil
        await abandon(session.id, toast: nil)
        await refreshWallet()
    }
}
