import Foundation

/// How a player identifies themselves: one or the other, never both.
/// The backend's request endpoints and verify all take this same shape.
public enum AuthIdentifier: Hashable, Sendable {
    case email(String)
    case phone(countryCode: String, number: String)
}

/// Which flow the player started. The backend branches on the purpose stored
/// with the code; the client only needs this to know where to go afterwards.
public enum AuthMode: Hashable, Sendable {
    case signIn
    case signUp
}

/// What the sign-in / sign-up / resend endpoints return.
/// `{"channel": "sms", "sent_to": "+974 •••• 1234", "expires_in": 600, "resend_after": 60}`
public struct OtpChallenge: Decodable, Hashable, Sendable {
    public enum Channel: String, Sendable, UnknownCaseRepresentable {
        case sms, email, unknown
    }

    @DefaultUnknown public var channel: Channel
    /// Masked destination to show the player.
    @DefaultEmpty public var sentTo: String
    @DefaultZero public var expiresIn: Int
    @DefaultZero public var resendAfter: Int

    public init(channel: Channel, sentTo: String, expiresIn: Int, resendAfter: Int) {
        self.channel = channel
        self.sentTo = sentTo
        self.expiresIn = expiresIn
        self.resendAfter = resendAfter
    }
}

/// The account behind a token (`UserSerializer`, `GET /auth/me`).
/// `id` is strict — a user without an ID is unusable; everything else is cosmetic.
public struct AccountUser: Decodable, Hashable, Sendable, Identifiable {
    public let id: PlayerID
    @DefaultEmpty public var firstName: String
    @DefaultEmpty public var lastName: String
    @DefaultEmpty public var email: String
    @DefaultEmpty public var countryCode: String
    @DefaultEmpty public var phone: String

    public var fullName: String {
        [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ")
    }

    public init(
        id: PlayerID,
        firstName: String = "",
        lastName: String = "",
        email: String = "",
        countryCode: String = "",
        phone: String = ""
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.countryCode = countryCode
        self.phone = phone
    }
}

/// A successful verification. Tokens are already stored by the time a feature sees this.
public struct AuthSession: Hashable, Sendable {
    public let user: AccountUser
    /// A deleted account that signing in brought back.
    public let reactivated: Bool
    /// The balance that came back with a reactivated account, when the server sent one.
    public let restoredBalance: Money?

    public init(user: AccountUser, reactivated: Bool = false, restoredBalance: Money? = nil) {
        self.user = user
        self.reactivated = reactivated
        self.restoredBalance = restoredBalance
    }
}
