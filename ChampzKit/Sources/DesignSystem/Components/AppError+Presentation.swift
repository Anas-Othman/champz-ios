import Foundation

/// How each `AppError` reads on screen. Core defines the cases; the words live here so
/// Core has no dependency on Localization.
public extension AppError {
    var title: LocalizedStringResource {
        switch self {
        case .offline: L10n.Errors.offlineTitle
        case .timeout: L10n.Errors.timeoutTitle
        case .unauthorized: L10n.Errors.unauthorizedTitle
        case .notFound: L10n.Errors.notFoundTitle
        case .forbidden, .validation, .rateLimited, .server, .payment, .decoding, .cancelled,
             .unknown: L10n.Errors.genericTitle
        }
    }

    var message: LocalizedStringResource {
        switch self {
        case .offline: L10n.Errors.offlineMessage
        case .timeout: L10n.Errors.timeoutMessage
        case .unauthorized: L10n.Errors.unauthorizedMessage
        case .notFound: L10n.Errors.notFoundMessage
        case let .server(message?, _):
            // The API's `details` is already a sentence written for the player.
            LocalizedStringResource(stringLiteral: message)
        case let .validation(fields) where !fields.isEmpty:
            LocalizedStringResource(stringLiteral: fields.map(\.message).joined(separator: "\n"))
        case let .rateLimited(code, retryAfter):
            LocalizedStringResource(stringLiteral: Self.rateLimitMessage(code: code, retryAfter: retryAfter))
        case .forbidden, .validation, .server, .payment, .decoding, .cancelled, .unknown: L10n.Errors.genericMessage
        }
    }

    var icon: AppIcon {
        switch self {
        case .offline: .offline
        case .notFound: .empty
        default: .warning
        }
    }

    /// 429s: an OTP cooldown ("code already sent") reads differently from a general throttle.
    private static func rateLimitMessage(code: String?, retryAfter: Int?) -> String {
        let wait = retryAfter.map(Self.humanDuration)
        switch (code, wait) {
        case (APIErrorCode.otpCooldown, let wait?): return L10n.RateLimits.otpCodeAlreadySentWait(wait)
        case (APIErrorCode.otpCooldown, nil): return String(localized: L10n.RateLimits.otpCodeAlreadySent)
        case let (_, wait?): return L10n.RateLimits.tooManyAttemptsWait(wait)
        case (_, nil): return String(localized: L10n.RateLimits.tooManyAttempts)
        }
    }

    private static func humanDuration(_ seconds: Int) -> String {
        switch seconds {
        case ..<60: L10n.RateLimits.durationSeconds(String(seconds))
        case 60 ..< 120: String(localized: L10n.RateLimits.durationOneMinute)
        case 120 ..< 3600: L10n.RateLimits.durationMinutes(String(seconds / 60))
        default: L10n.RateLimits.durationHours(String(seconds / 3600))
        }
    }
}
