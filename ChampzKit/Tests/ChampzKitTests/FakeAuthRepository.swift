import Foundation
@testable import ChampzKit

/// Scripted `AuthRepository` for view-model tests. Records calls, returns what it is told.
actor FakeAuthRepository: AuthRepository {
    enum Call: Equatable {
        case signIn(AuthIdentifier), signUp(AuthIdentifier), resend(AuthIdentifier), verify(AuthIdentifier, String), me,
             logout
    }

    private(set) var calls: [Call] = []
    var challenge: Result<OtpChallenge, AppError> = .success(OtpChallenge(
        channel: .sms,
        sentTo: "+974 •••• 1234",
        expiresIn: 600,
        resendAfter: 30
    ))
    var verifyResult: Result<AuthSession, AppError> = .success(AuthSession(
        user: AccountUser(
            id: PlayerID("7"),
            firstName: "Anas",
            lastName: "E",
            email: "",
            countryCode: "+974",
            phone: "55512345"
        ),
        reactivated: false,
        restoredBalance: nil
    ))

    func set(challenge: Result<OtpChallenge, AppError>) {
        self.challenge = challenge
    }

    func set(verify: Result<AuthSession, AppError>) {
        verifyResult = verify
    }

    func requestSignIn(_ identifier: AuthIdentifier) async throws(AppError) -> OtpChallenge {
        calls.append(.signIn(identifier))
        return try challenge.get()
    }

    func requestSignUp(_ identifier: AuthIdentifier) async throws(AppError) -> OtpChallenge {
        calls.append(.signUp(identifier))
        return try challenge.get()
    }

    func resendCode(_ identifier: AuthIdentifier) async throws(AppError) -> OtpChallenge {
        calls.append(.resend(identifier))
        return try challenge.get()
    }

    func verify(_ identifier: AuthIdentifier, code: String) async throws(AppError) -> AuthSession {
        calls.append(.verify(identifier, code))
        return try verifyResult.get()
    }

    func currentUser() async throws(AppError) -> AccountUser {
        calls.append(.me)
        return try verifyResult.get().user
    }

    func logoutEverywhere() async throws(AppError) {
        calls.append(.logout)
    }
}
