import Foundation

public enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

/// A typed description of one API call. `Data` defines these per feature
/// (`AuthAPI.signIn(...)`); `HTTPClient` sends them. The response type travels with
/// the endpoint so call sites cannot decode the wrong thing.
public struct Endpoint<Response: Decodable & Sendable>: Sendable {
    public var method: HTTPMethod
    /// Path relative to the base URL, e.g. "/api/v1/games/12/join/".
    public var path: String
    public var query: [URLQueryItem]
    public var body: Data?
    public var headers: [String: String]
    /// Default-deny: every endpoint needs a bearer token unless it says otherwise.
    public var requiresAuth: Bool
    /// Sent as `Idempotency-Key` on endpoints the contract marks with it (checkout, top-up, transfer).
    public var idempotencyKey: String?

    public init(
        _ method: HTTPMethod,
        _ path: String,
        query: [URLQueryItem] = [],
        body: Data? = nil,
        headers: [String: String] = [:],
        requiresAuth: Bool = true,
        idempotencyKey: String? = nil
    ) {
        self.method = method
        self.path = path
        self.query = query
        self.body = body
        self.headers = headers
        self.requiresAuth = requiresAuth
        self.idempotencyKey = idempotencyKey
    }

    /// Attaches a JSON body. Encoding failures are programmer errors, so this traps in debug.
    public func json(_ value: some Encodable) -> Self {
        var copy = self
        do {
            copy.body = try JSONEncoder.api().encode(value)
        } catch {
            assertionFailure("Failed to encode request body for \(path): \(error)")
            copy.body = nil
        }
        copy.headers["Content-Type"] = "application/json"
        return copy
    }

    public func query(_ items: [String: String?]) -> Self {
        var copy = self
        copy.query += items.compactMap { key, value in value.map { URLQueryItem(name: key, value: $0) } }
            .sorted { $0.name < $1.name }
        return copy
    }
}

/// Response type for endpoints that return nothing useful (204, or a body we ignore).
public struct NoContent: Decodable, Sendable, Equatable {
    public init() {}
    public init(from decoder: any Decoder) throws {}
}
