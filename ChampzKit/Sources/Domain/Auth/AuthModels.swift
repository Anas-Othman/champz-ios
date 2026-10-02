import Core
import Foundation

/// How a player identifies themselves: one or the other, never both.
/// The backend's three request endpoints and verify all take this same shape.
public enum AuthIdentifier: Hashable, Sendable {
    case email(String)
    case phone(countryCode: String, number: String)

    public var isEmail: Bool {
        if case .email = self {
            return true
        }
        return false
    }
}

/// Which flow the player started. The backend branches on the purpose stored
/// with the code, so the client only needs this to know where to go afterwards.
public enum AuthMode: Hashable, Sendable {
    case signIn
    case signUp
}

/// What the request endpoints return: where the code went and when a resend is allowed.
public struct OtpChallenge: Hashable, Sendable {
    public enum Channel: String, Sendable, UnknownCaseRepresentable {
        case sms, email, unknown
    }

    public let channel: Channel
    /// Masked destination to show the player, e.g. "+974 •••• 1234".
    public let sentTo: String
    public let expiresIn: Int
    public let resendAfter: Int

    public init(channel: Channel, sentTo: String, expiresIn: Int, resendAfter: Int) {
        self.channel = channel
        self.sentTo = sentTo
        self.expiresIn = expiresIn
        self.resendAfter = resendAfter
    }
}

/// The account behind a token, as `verify-otp` and `GET /auth/me` describe it.
public struct AccountUser: Hashable, Sendable, Identifiable {
    public let id: PlayerID
    public let firstName: String
    public let lastName: String
    public let email: String
    public let countryCode: String
    public let phone: String

    public init(id: PlayerID, firstName: String, lastName: String, email: String, countryCode: String, phone: String) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.countryCode = countryCode
        self.phone = phone
    }

    public var fullName: String {
        [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ")
    }
}

/// A successful verification. Tokens are already stored by the time a feature sees this.
public struct AuthSession: Hashable, Sendable {
    public let user: AccountUser
    /// A deleted account that signing in brought back (backend T18).
    public let reactivated: Bool
    /// The balance that came back with a reactivated account, when the server sent one.
    public let restoredBalance: Money?

    public init(user: AccountUser, reactivated: Bool, restoredBalance: Money?) {
        self.user = user
        self.reactivated = reactivated
        self.restoredBalance = restoredBalance
    }
}

/// The auth feature's view of the backend. Implemented in Data.
public protocol AuthRepository: Sendable {
    /// Request a sign-in code. Identical response whether or not the account exists.
    func requestSignIn(_ identifier: AuthIdentifier) async throws(AppError) -> OtpChallenge
    /// Request a sign-up code. Profile fields are captured at verification by the server.
    func requestSignUp(_ identifier: AuthIdentifier) async throws(AppError) -> OtpChallenge
    /// Reissue the outstanding code for this identifier.
    func resendCode(_ identifier: AuthIdentifier) async throws(AppError) -> OtpChallenge
    /// Exchange the code for tokens. On success the session is persisted before returning.
    func verify(_ identifier: AuthIdentifier, code: String) async throws(AppError) -> AuthSession
    /// The account behind the current token. Fails with `.unauthorized` when the session is dead.
    func currentUser() async throws(AppError) -> AccountUser
    /// Server-side logout of every device, then local sign-out.
    func logoutEverywhere() async throws(AppError)
}
