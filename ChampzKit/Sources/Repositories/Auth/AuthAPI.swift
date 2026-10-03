import Foundation

/// Endpoints under /api/v1/auth/ and /api/v1/app/auth/.
/// Request bodies and response shapes that exist only for the wire live here too.
enum AuthAPI {
    static func signIn(_ identifier: AuthIdentifier) -> Endpoint<OtpChallenge> {
        Endpoint(.post, "/api/v1/app/auth/signin/", requiresAuth: false)
            .json(IdentifierBody(identifier))
    }

    static func signUp(_ identifier: AuthIdentifier) -> Endpoint<OtpChallenge> {
        Endpoint(.post, "/api/v1/app/auth/signup/", requiresAuth: false)
            .json(IdentifierBody(identifier))
    }

    static func resend(_ identifier: AuthIdentifier) -> Endpoint<OtpChallenge> {
        Endpoint(.post, "/api/v1/app/auth/resend-otp/", requiresAuth: false)
            .json(IdentifierBody(identifier))
    }

    /// Shared by both flows: the server branches on the purpose stored with the code.
    static func verify(_ identifier: AuthIdentifier, code: String) -> Endpoint<VerifyOtpResponse> {
        Endpoint(.post, "/api/v1/app/auth/verify-otp/", requiresAuth: false)
            .json(VerifyOtpBody(identifier: identifier, otp: code))
    }

    /// Anonymous by design: the refresh token in the body is the credential. Tokens rotate.
    static func refresh(_ refreshToken: String) -> Endpoint<TokenPair> {
        Endpoint(.post, "/api/v1/auth/token/refresh/", requiresAuth: false)
            .json(["refresh": refreshToken])
    }

    static func me() -> Endpoint<AccountUser> {
        Endpoint(.get, "/api/v1/auth/me/")
    }

    static func logoutAll() -> Endpoint<NoContent> {
        Endpoint(.post, "/api/v1/auth/logout-all/")
    }
}

/// The request endpoints take the same body: email, or phone + country code.
/// Fields the player did not use are sent empty, as the current app does.
struct IdentifierBody: Encodable {
    var email = ""
    var phone = ""
    var countryCode = ""

    init(_ identifier: AuthIdentifier) {
        switch identifier {
        case let .email(address):
            email = address
        case let .phone(code, number):
            phone = number
            countryCode = code
        }
    }
}

struct VerifyOtpBody: Encodable {
    let email: String
    let phone: String
    let countryCode: String
    let otp: String

    init(identifier: AuthIdentifier, otp: String) {
        let base = IdentifierBody(identifier)
        email = base.email
        phone = base.phone
        countryCode = base.countryCode
        self.otp = otp
    }
}

/// Both fields required; a missing token is a hard failure.
struct TokenPair: Decodable, Equatable {
    let access: String
    let refresh: String
}

/// `verify-otp` 200 body: tokens, the user, and reactivation extras when an account came back.
struct VerifyOtpResponse: Decodable {
    let access: String
    let refresh: String
    let user: AccountUser
    @DefaultFalse var reactivated: Bool
    @DefaultEmpty var walletBalance: String
}
