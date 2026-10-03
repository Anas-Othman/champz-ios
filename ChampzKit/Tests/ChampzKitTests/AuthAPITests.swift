import Foundation
import Testing
@testable import ChampzKit

/// A stub `HTTPClient`: answers each endpoint with canned JSON, no network.
actor StubHTTPClient: HTTPClientProtocol {
    private var responses: [String: Result<Data, AppError>] = [:]
    private(set) var sentPaths: [String] = []

    func respond(to path: String, with json: String) {
        responses[path] = .success(Data(json.utf8))
    }

    func fail(_ path: String, with error: AppError) {
        responses[path] = .failure(error)
    }

    func send<R>(_ endpoint: Endpoint<R>) async throws(AppError) -> R {
        sentPaths.append(endpoint.path)
        guard let response = responses[endpoint.path] else { throw .notFound }
        let data: Data
        do { data = try response.get() } catch { throw error }
        do {
            return try JSONDecoder.api().decode(R.self, from: data)
        } catch {
            throw .decoding(String(describing: error))
        }
    }
}

struct AuthAPITests {
    @Test func refreshEndpointIsAnonymousAndCarriesTheToken() throws {
        let endpoint = AuthAPI.refresh("r1")
        #expect(endpoint.method == .post)
        #expect(endpoint.path == "/api/v1/auth/token/refresh/")
        #expect(!endpoint.requiresAuth)
        let body = try #require(endpoint.body)
        #expect(try JSONDecoder().decode([String: String].self, from: body) == ["refresh": "r1"])
    }

    @Test func tokenPairDecodesFromFixture() throws {
        let url = try #require(Bundle.module.url(
            forResource: "token_refresh",
            withExtension: "json",
            subdirectory: "Fixtures"
        ))
        let pair = try JSONDecoder.api().decode(TokenPair.self, from: Data(contentsOf: url))
        #expect(pair.access.hasPrefix("eyJ"))
        #expect(!pair.refresh.isEmpty)
    }

    @Test func liveRefresherMapsToAuthTokens() async throws {
        let stub = StubHTTPClient()
        await stub.respond(to: "/api/v1/auth/token/refresh/", with: #"{"access": "A", "refresh": "R"}"#)
        let tokens = try await LiveTokenRefresher(http: stub).refresh(using: "old")
        #expect(tokens == AuthTokens(access: "A", refresh: "R"))
    }

    @Test func missingTokenInResponseFailsLoudly() async {
        let stub = StubHTTPClient()
        await stub.respond(to: "/api/v1/auth/token/refresh/", with: #"{"access": "A"}"#)
        await #expect(throws: AppError.self) {
            try await LiveTokenRefresher(http: stub).refresh(using: "old")
        }
    }
}
