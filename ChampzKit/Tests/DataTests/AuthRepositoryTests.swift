import Core
import Domain
import Foundation
import Testing
@testable import Data

struct AuthRepositoryTests {
    private func fixture(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }

    @Test func identifierBodyMatchesTheContract() throws {
        let phone = try JSONDecoder().decode(
            [String: String].self,
            from: #require(AuthAPI.signIn(.phone(countryCode: "+974", number: "55512345")).body)
        )
        #expect(phone == ["email": "", "phone": "55512345", "country_code": "+974"])

        let email = try JSONDecoder().decode(
            [String: String].self,
            from: #require(AuthAPI.signUp(.email("a@b.co")).body)
        )
        #expect(email == ["email": "a@b.co", "phone": "", "country_code": ""])

        let verify = try JSONDecoder().decode(
            [String: String].self,
            from: #require(AuthAPI.verify(.email("a@b.co"), code: "123456").body)
        )
        #expect(verify["otp"] == "123456")
        #expect(!AuthAPI.verify(.email("a@b.co"), code: "1").requiresAuth)
        #expect(AuthAPI.me().requiresAuth)
    }

    @Test func challengeDecodesFromFixtureAndFromBareBody() throws {
        let full = try JSONDecoder.api().decode(OtpChallengeDTO.self, from: fixture("otp_challenge")).toDomain()
        #expect(full == OtpChallenge(channel: .sms, sentTo: "+974 •••• 1234", expiresIn: 600, resendAfter: 60))

        let bare = try JSONDecoder.api().decode(OtpChallengeDTO.self, from: Data("{}".utf8)).toDomain()
        #expect(bare == OtpChallenge(channel: .unknown, sentTo: "", expiresIn: 0, resendAfter: 0))
    }

    @Test func verifyStoresTokensAndMapsUser() async throws {
        let stub = StubHTTPClient()
        try await stub.respond(
            to: "/api/v1/app/auth/verify-otp/",
            with: #require(String(data: fixture("verify_otp"), encoding: .utf8))
        )
        let session = SessionStore(store: InMemorySecureStore())
        let repo = LiveAuthRepository(http: stub, session: session)

        let result = try await repo.verify(.phone(countryCode: "+974", number: "55512345"), code: "123456")

        #expect(result.user.id == PlayerID("42"))
        #expect(result.user.fullName == "Anas Ezzat")
        #expect(!result.reactivated)
        #expect(result.restoredBalance == nil)
        #expect(await session.accessToken == "access.fixture")
    }

    @Test func reactivatedAccountCarriesItsBalance() async throws {
        let stub = StubHTTPClient()
        await stub.respond(to: "/api/v1/app/auth/verify-otp/", with: """
        {"access": "a", "refresh": "r", "reactivated": true, "wallet_balance": "15.50",
         "user": {"id": "9", "first_name": null, "email": null}}
        """)
        let repo = LiveAuthRepository(http: stub, session: SessionStore(store: InMemorySecureStore()))
        let result = try await repo.verify(.email("a@b.co"), code: "123456")
        #expect(result.reactivated)
        #expect(try result.restoredBalance == Money(#require(Decimal(string: "15.50")), currency: "QAR"))
        #expect(result.user.id == PlayerID("9"))
        #expect(result.user.firstName == "")
    }

    @Test func verifyWithoutTokensFailsLoudly() async {
        let stub = StubHTTPClient()
        await stub.respond(to: "/api/v1/app/auth/verify-otp/", with: #"{"user": {"id": 1}}"#)
        let session = SessionStore(store: InMemorySecureStore())
        let repo = LiveAuthRepository(http: stub, session: session)
        await #expect(throws: AppError.self) {
            try await repo.verify(.email("a@b.co"), code: "123456")
        }
        #expect(await session.accessToken == nil)
    }
}
