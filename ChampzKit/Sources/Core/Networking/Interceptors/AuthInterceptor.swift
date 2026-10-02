import Foundation

/// Attaches the bearer token and, on a 401, asks `SessionStore` to refresh once and
/// lets `HTTPClient` resend. Concurrent 401s share one refresh: the backend rotates
/// refresh tokens (each is single-use), so two refreshes in flight would log the user out.
public struct AuthInterceptor: RequestInterceptor {
    private let session: SessionStore

    public init(session: SessionStore) {
        self.session = session
    }

    public func prepare(_ request: URLRequest, context: RequestContext) async throws(AppError) -> URLRequest {
        guard context.requiresAuth else { return request }
        var request = request
        if let token = await session.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    public func shouldRetry(after response: ResponseInfo, context: RequestContext, attempt: Int) async -> Bool {
        guard response.statusCode == 401, context.requiresAuth, attempt == 0 else { return false }
        return await session.refresh()
    }
}
