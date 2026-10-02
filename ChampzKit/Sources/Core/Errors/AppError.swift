import Foundation

/// The only error type that crosses a module boundary. Repositories and `HTTPClient`
/// translate transport, HTTP and decoding failures into one of these cases; features
/// never see `URLError`, `DecodingError` or status codes. Presentation (titles, messages)
/// lives in DesignSystem's `AppError+Presentation`.
public enum AppError: Error, Equatable, Sendable {
    /// No network, or the host could not be reached.
    case offline
    /// The request timed out.
    case timeout
    /// The session ended: a 401 that a token refresh could not recover.
    case unauthorized
    /// 403: signed in, but not allowed (or the account is inactive).
    case forbidden
    /// 404.
    case notFound
    /// 400/422 with per-field messages from the API.
    case validation([FieldError])
    /// 429. `code` distinguishes an OTP cooldown from a general throttle; `retryAfter` is seconds.
    case rateLimited(code: String?, retryAfter: Int?)
    /// Any other non-2xx. `message` is the sentence the API wrote for the player; `code` its machine code.
    case server(message: String?, code: String?)
    /// A payment-specific failure (section 9 of the guide).
    case payment(PaymentFailure)
    /// The response arrived but a field we never default was missing or malformed. Always reported.
    case decoding(String)
    /// The caller cancelled the task.
    case cancelled
    case unknown

    /// Whether offering a "Try again" action makes sense.
    public var isRetryable: Bool {
        switch self {
        case .offline, .timeout, .server, .unknown: true
        case .unauthorized, .forbidden, .notFound, .validation, .rateLimited, .payment, .decoding, .cancelled: false
        }
    }

    /// Whether the error should be reported to Sentry. Expected user-facing conditions are not.
    public var isReportable: Bool {
        switch self {
        case .decoding, .unknown, .server: true
        case .offline, .timeout, .unauthorized, .forbidden, .notFound, .validation, .rateLimited, .payment,
             .cancelled: false
        }
    }

    /// The backend's machine code, when the error carried one.
    public var apiCode: String? {
        switch self {
        case let .server(_, code), let .rateLimited(code, _): code
        default: nil
        }
    }
}

public struct FieldError: Equatable, Sendable, Hashable {
    public let field: String
    public let message: String

    public init(field: String, message: String) {
        self.field = field
        self.message = message
    }
}

public enum PaymentFailure: Equatable, Sendable {
    case insufficientFunds
    case declined
    case sessionExpired
    case cancelled
    case unknown(code: String?)
}
