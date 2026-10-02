import Core
import Foundation

/// `SessionStore`'s refresher. Uses its own `HTTPClient` without the auth interceptor
/// so a refresh can never trigger another refresh.
public struct LiveTokenRefresher: TokenRefreshing {
    private let http: any HTTPClientProtocol

    public init(http: any HTTPClientProtocol) {
        self.http = http
    }

    public func refresh(using refreshToken: String) async throws(AppError) -> AuthTokens {
        let pair = try await http.send(AuthAPI.refresh(refreshToken))
        return AuthTokens(access: pair.access, refresh: pair.refresh)
    }
}
