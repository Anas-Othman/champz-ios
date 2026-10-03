import Foundation

/// The auth feature's view of the backend. View models depend on this protocol;
/// tests use a fake, the app uses `LiveAuthRepository`.
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

/// Talks to the backend through `HTTPClient` and hands tokens to `SessionStore`;
/// the only place tokens pass from a response into storage.
public struct LiveAuthRepository: AuthRepository {
    let http: any HTTPClientProtocol
    let session: SessionStore
    /// Currency for a reactivated account's restored balance until the server names one.
    var defaultCurrency = "QAR"

    public init(http: any HTTPClientProtocol, session: SessionStore) {
        self.http = http
        self.session = session
    }

    public func requestSignIn(_ identifier: AuthIdentifier) async throws(AppError) -> OtpChallenge {
        try await http.send(AuthAPI.signIn(identifier))
    }

    public func requestSignUp(_ identifier: AuthIdentifier) async throws(AppError) -> OtpChallenge {
        try await http.send(AuthAPI.signUp(identifier))
    }

    public func resendCode(_ identifier: AuthIdentifier) async throws(AppError) -> OtpChallenge {
        try await http.send(AuthAPI.resend(identifier))
    }

    public func verify(_ identifier: AuthIdentifier, code: String) async throws(AppError) -> AuthSession {
        let response = try await http.send(AuthAPI.verify(identifier, code: code))
        await session.store(AuthTokens(access: response.access, refresh: response.refresh))
        let balance = response.reactivated ? Decimal(string: response.walletBalance, locale: .posix) : nil
        return AuthSession(
            user: response.user,
            reactivated: response.reactivated,
            restoredBalance: balance.map { Money($0, currency: defaultCurrency) }
        )
    }

    public func currentUser() async throws(AppError) -> AccountUser {
        try await http.send(AuthAPI.me())
    }

    public func logoutEverywhere() async throws(AppError) {
        _ = try await http.send(AuthAPI.logoutAll())
        await session.clear()
    }
}
