import Core
import Domain
import Foundation

/// Endpoints under /api/v1/auth/ and /api/v1/app/auth/ (contracts/openapi.yaml).
/// Request/response DTOs sit beside the endpoints that use them.
enum AuthAPI {
    static func signIn(_ identifier: AuthIdentifier) -> Endpoint<OtpChallengeDTO> {
        Endpoint(.post, "/api/v1/app/auth/signin/", requiresAuth: false)
            .json(IdentifierBody(identifier))
    }

    static func signUp(_ identifier: AuthIdentifier) -> Endpoint<OtpChallengeDTO> {
        Endpoint(.post, "/api/v1/app/auth/signup/", requiresAuth: false)
            .json(IdentifierBody(identifier))
    }

    static func resend(_ identifier: AuthIdentifier) -> Endpoint<OtpChallengeDTO> {
        Endpoint(.post, "/api/v1/app/auth/resend-otp/", requiresAuth: false)
            .json(IdentifierBody(identifier))
    }

    /// Shared by both flows: the server branches on the purpose stored with the code.
    static func verify(_ identifier: AuthIdentifier, code: String) -> Endpoint<VerifyOtpResponseDTO> {
        Endpoint(.post, "/api/v1/app/auth/verify-otp/", requiresAuth: false)
            .json(VerifyOtpBody(identifier: identifier, otp: code))
    }

    /// Anonymous by design: the refresh token in the body is the credential. Tokens rotate.
    static func refresh(_ refreshToken: String) -> Endpoint<TokenPairDTO> {
        Endpoint(.post, "/api/v1/auth/token/refresh/", requiresAuth: false)
            .json(RefreshRequestDTO(refresh: refreshToken))
    }

    static func me() -> Endpoint<UserDTO> {
        Endpoint(.get, "/api/v1/auth/me/")
    }

    static func logoutAll() -> Endpoint<NoContent> {
        Endpoint(.post, "/api/v1/auth/logout-all/")
    }
}

// MARK: - Request bodies

/// The three request endpoints take the same body: email, or phone + country code.
/// Fields the player did not use are sent empty, as the Flutter app does.
struct IdentifierBody: Encodable {
    let email: String
    let phone: String
    let countryCode: String

    init(_ identifier: AuthIdentifier) {
        switch identifier {
        case let .email(address):
            email = address
            phone = ""
            countryCode = ""
        case let .phone(code, number):
            email = ""
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

struct RefreshRequestDTO: Encodable {
    let refresh: String
}

// MARK: - Responses

/// `{"channel": "sms", "sent_to": "+974 •••• 1234", "expires_in": 600, "resend_after": 60}`
struct OtpChallengeDTO: Decodable, Equatable {
    @DefaultUnknown var channel: OtpChallenge.Channel
    @DefaultEmpty var sentTo: String
    @DefaultZero var expiresIn: Int
    @DefaultZero var resendAfter: Int
}

/// `TokenRefresh` schema: both fields required; a missing token is a hard failure.
struct TokenPairDTO: Decodable, Equatable {
    let access: String
    let refresh: String
}

/// `verify-otp` 200 body: tokens, the user, and reactivation extras when an account came back.
struct VerifyOtpResponseDTO: Decodable, Equatable {
    let access: String
    let refresh: String
    let user: UserDTO
    @DefaultFalse var reactivated: Bool
    @DefaultEmpty var walletBalance: String
}

/// `UserSerializer` / `GET /auth/me`. `id` is strict (a user without an ID is unusable);
/// everything else is cosmetic and defaults.
struct UserDTO: Decodable, Equatable {
    let id: PlayerID
    @DefaultEmpty var firstName: String
    @DefaultEmpty var lastName: String
    @DefaultEmpty var email: String
    @DefaultEmpty var countryCode: String
    @DefaultEmpty var phone: String
    @DefaultEmpty var userType: String
}
