import Core
import Domain
import Foundation

/// The live `AuthRepository`. Talks to the backend through `HTTPClient` and hands
/// tokens to `SessionStore`; it is the only place tokens pass from a response into storage.
public struct LiveAuthRepository: AuthRepository {
    private let http: any HTTPClientProtocol
    private let session: SessionStore
    /// Currency for a reactivated account's restored balance until the server names one.
    private let defaultCurrency: String

    public init(http: any HTTPClientProtocol, session: SessionStore, defaultCurrency: String = "QAR") {
        self.http = http
        self.session = session
        self.defaultCurrency = defaultCurrency
    }

    public func requestSignIn(_ identifier: AuthIdentifier) async throws(AppError) -> OtpChallenge {
        try await http.send(AuthAPI.signIn(identifier)).toDomain()
    }

    public func requestSignUp(_ identifier: AuthIdentifier) async throws(AppError) -> OtpChallenge {
        try await http.send(AuthAPI.signUp(identifier)).toDomain()
    }

    public func resendCode(_ identifier: AuthIdentifier) async throws(AppError) -> OtpChallenge {
        try await http.send(AuthAPI.resend(identifier)).toDomain()
    }

    public func verify(_ identifier: AuthIdentifier, code: String) async throws(AppError) -> AuthSession {
        let response = try await http.send(AuthAPI.verify(identifier, code: code))
        await session.store(AuthTokens(access: response.access, refresh: response.refresh))
        return AuthSession(
            user: response.user.toDomain(),
            reactivated: response.reactivated,
            restoredBalance: response.reactivated
                ? Decimal(string: response.walletBalance, locale: Locale(identifier: "en_US_POSIX")).map { Money(
                    $0,
                    currency: defaultCurrency
                ) }
                : nil
        )
    }

    public func currentUser() async throws(AppError) -> AccountUser {
        try await http.send(AuthAPI.me()).toDomain()
    }

    public func logoutEverywhere() async throws(AppError) {
        _ = try await http.send(AuthAPI.logoutAll())
        await session.clear()
    }
}

// MARK: - Mappers (DTO → domain)

extension OtpChallengeDTO {
    func toDomain() -> OtpChallenge {
        OtpChallenge(channel: channel, sentTo: sentTo, expiresIn: expiresIn, resendAfter: resendAfter)
    }
}

extension UserDTO {
    func toDomain() -> AccountUser {
        AccountUser(
            id: id,
            firstName: firstName,
            lastName: lastName,
            email: email,
            countryCode: countryCode,
            phone: phone
        )
    }
}
