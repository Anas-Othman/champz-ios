import Foundation

/// Turns HTTP failures and transport errors into `AppError`.
///
/// The backend wraps every error in one envelope:
/// ```json
/// {"error": {"code": "02023", "message": "Invalid OTP", "details": "The one-time password…",
///            "errors": [{"field": "phone", "message": "…"}], "request_id": "…"}}
/// ```
/// `details` is the sentence written for the player; `message` is the short title.
/// Plain DRF shapes (`{"detail": …}`, `{"field": ["msg"]}`) are still understood for
/// endpoints that bypass the handler.
public enum APIErrorMapper {
    public static func map(statusCode: Int, body: Data) -> AppError {
        let payload = Payload(body)
        switch statusCode {
        case 401: return .unauthorized
        case 403: return .forbidden
        case 404: return .notFound
        case 429: return .rateLimited(code: payload.code, retryAfter: payload.retryAfterSeconds)
        case 408, 504: return .timeout
        case 400, 402, 409, 422:
            if let code = payload.code, let payment = paymentFailure(for: code) {
                return .payment(payment)
            }
            // Validation errors carry per-field messages; everything else is a plain server message.
            if payload.code == APIErrorCode.validation || payload.code == nil, !payload.fieldErrors.isEmpty {
                return .validation(payload.fieldErrors)
            }
            return .server(message: payload.userMessage, code: payload.code)
        default:
            return .server(message: payload.userMessage, code: payload.code)
        }
    }

    public static func map(urlError: URLError) -> AppError {
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost,
             .dnsLookupFailed, .internationalRoamingOff, .dataNotAllowed:
            .offline
        case .timedOut:
            .timeout
        case .cancelled:
            .cancelled
        default:
            .unknown
        }
    }

    /// Payment codes the checkout endpoints return (PAYMENT_SCENARIOS_MATRIX.md).
    private static func paymentFailure(for code: String) -> PaymentFailure? {
        switch code.uppercased() {
        case "INSUFFICIENT_FUNDS": .insufficientFunds
        case "PAYMENT_DECLINED", "CARD_DECLINED": .declined
        case "SESSION_EXPIRED", "PAYMENT_SESSION_EXPIRED": .sessionExpired
        default: nil
        }
    }

    /// Tolerant view of an error body. Never throws; every field is optional.
    private struct Payload {
        let code: String?
        let message: String?
        let details: String?
        let fieldErrors: [FieldError]

        /// The sentence to show: the envelope's `details`, else its `message`, else DRF's `detail`.
        var userMessage: String? {
            details ?? message
        }

        /// `retry_after_seconds` rides in the envelope's `errors` list on cooldown/throttle responses.
        var retryAfterSeconds: Int? {
            fieldErrors.first { $0.field == "retry_after_seconds" }.flatMap { Int($0.message) }
        }

        init(_ data: Data) {
            guard !data.isEmpty, let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                code = nil
                message = nil
                details = nil
                fieldErrors = []
                return
            }
            if let envelope = object["error"] as? [String: Any] {
                code = envelope["code"] as? String
                message = envelope["message"] as? String
                details = envelope["details"] as? String
                fieldErrors = ((envelope["errors"] as? [[String: Any]]) ?? []).compactMap { item in
                    guard let field = item["field"] as? String,
                          let text = item["message"] as? String else { return nil }
                    return FieldError(field: field, message: text)
                }
                return
            }
            code = object["code"] as? String
            message = (object["detail"] as? String) ?? (object["message"] as? String) ?? (object["error"] as? String)
            details = nil
            fieldErrors = object
                .filter { !["detail", "message", "error", "code", "non_field_errors"].contains($0.key) }
                .compactMap { key, value -> FieldError? in
                    if let messages = value as? [String], let first = messages.first {
                        return FieldError(
                            field: key,
                            message: first
                        )
                    }
                    if let text = value as? String {
                        return FieldError(field: key, message: text)
                    }
                    return nil
                }
                .sorted { $0.field < $1.field }
        }
    }
}
