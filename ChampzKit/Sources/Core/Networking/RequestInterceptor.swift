import Foundation

/// What an interceptor may know about a request without seeing the generic endpoint.
public struct RequestContext: Sendable {
    public let path: String
    public let requiresAuth: Bool
    public let idempotencyKey: String?
}

/// Status, headers and timing of a response.
public struct ResponseInfo: Sendable {
    public let statusCode: Int
    public let headers: [String: String]
    public let duration: Duration
}

/// A hook into `HTTPClient`'s pipeline. Interceptors run in the order they are registered.
public protocol RequestInterceptor: Sendable {
    func prepare(_ request: URLRequest, context: RequestContext) async throws(AppError) -> URLRequest
    /// Called with the full exchange. Bodies are provided so a debug logger can print them;
    /// production interceptors must not persist or forward them.
    func didReceive(_ response: ResponseInfo, body: Data, for request: URLRequest, context: RequestContext) async
    /// Return true to have the request rebuilt (through `prepare` again) and resent once.
    func shouldRetry(after response: ResponseInfo, context: RequestContext, attempt: Int) async -> Bool
}

public extension RequestInterceptor {
    func prepare(_ request: URLRequest, context: RequestContext) async throws(AppError) -> URLRequest {
        request
    }

    func didReceive(_ response: ResponseInfo, body: Data, for request: URLRequest, context: RequestContext) async {}

    func shouldRetry(after response: ResponseInfo, context: RequestContext, attempt: Int) async -> Bool {
        false
    }
}
