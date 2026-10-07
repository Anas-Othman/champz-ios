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

    /// Attaches a `multipart/form-data` body: text fields plus an optional file (profile photo).
    public func multipart(_ fields: [String: String], file: MultipartFile? = nil) -> Self {
        let boundary = "champz-\(UUID().uuidString)"
        var body = Data()
        func append(_ text: String) {
            body.append(Data(text.utf8))
        }
        for (name, value) in fields.sorted(by: { $0.key < $1.key }) {
            append("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n")
        }
        if let file {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"\(file.name)\"; filename=\"\(file.filename)\"\r\n")
            append("Content-Type: \(file.mimeType)\r\n\r\n")
            body.append(file.data)
            append("\r\n")
        }
        append("--\(boundary)--\r\n")
        var copy = self
        copy.body = body
        copy.headers["Content-Type"] = "multipart/form-data; boundary=\(boundary)"
        return copy
    }

    public func query(_ items: [String: String?]) -> Self {
        var copy = self
        copy.query += items.compactMap { key, value in value.map { URLQueryItem(name: key, value: $0) } }
            .sorted { $0.name < $1.name }
        return copy
    }
}

/// A file part of a multipart body.
public struct MultipartFile: Sendable, Equatable {
    public let name: String
    public let filename: String
    public let mimeType: String
    public let data: Data

    /// A JPEG under the given form field name.
    public static func jpeg(_ data: Data, name: String) -> MultipartFile {
        MultipartFile(name: name, filename: "\(name).jpg", mimeType: "image/jpeg", data: data)
    }
}

/// Response type for endpoints that return nothing useful (204, or a body we ignore).
public struct NoContent: Decodable, Sendable, Equatable {
    public init() {}
    public init(from decoder: any Decoder) throws {}
}
