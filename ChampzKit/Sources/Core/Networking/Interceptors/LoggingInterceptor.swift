import Foundation

/// Logs every exchange. Two levels:
/// - **summary** (always): method, path, status, duration — safe for production.
/// - **bodies** (`logsBodies: true`, debug builds only): full URL, request headers and body,
///   response body, pretty-printed. The `Authorization` header and `access`/`refresh` token
///   values are redacted so a pasted log never contains a usable credential.
///
/// Filter in Xcode's console or Console.app by subsystem `me.champz.app`, category `network`.
public struct LoggingInterceptor: RequestInterceptor {
    public typealias Breadcrumb = @Sendable (_ path: String, _ status: Int, _ milliseconds: Int) -> Void

    private let logsBodies: Bool
    private let breadcrumb: Breadcrumb?

    /// `breadcrumb` lets the app forward each response to Sentry without Core importing it.
    public init(logsBodies: Bool = false, breadcrumb: Breadcrumb? = nil) {
        self.logsBodies = logsBodies
        self.breadcrumb = breadcrumb
    }

    public func didReceive(
        _ response: ResponseInfo,
        body: Data,
        for request: URLRequest,
        context: RequestContext
    ) async {
        let ms = Int(response.duration / .milliseconds(1))
        let method = request.httpMethod ?? "?"
        let summary = "\(method) \(context.path) → \(response.statusCode) in \(ms)ms"
        if (200 ..< 400).contains(response.statusCode) {
            Log.network.info("\(summary, privacy: .public)")
        } else {
            Log.network.error("\(summary, privacy: .public)")
        }
        breadcrumb?(context.path, response.statusCode, ms)

        guard logsBodies else { return }
        var lines = ["┌─ \(summary)"]
        lines.append("│ URL: \(request.url?.absoluteString ?? "-")")
        for (name, value) in (request.allHTTPHeaderFields ?? [:]).sorted(by: { $0.key < $1.key }) {
            lines.append("│ > \(name): \(name.lowercased() == "authorization" ? "Bearer <redacted>" : value)")
        }
        lines.append("│ Request body: \(Self.render(request.httpBody))")
        lines.append("│ Response body: \(Self.render(body))")
        lines.append("└─")
        Self.emit(lines.joined(separator: "\n"))
    }

    // MARK: - Formatting

    /// Pretty-prints JSON with token values redacted; falls back to raw text.
    static func render(_ data: Data?) -> String {
        guard let data, !data.isEmpty else { return "<empty>" }
        if let object = try? JSONSerialization.jsonObject(with: data),
           let pretty = try? JSONSerialization.data(
               withJSONObject: redact(object),
               options: [.prettyPrinted, .sortedKeys]
           ),
           let text = String(data: pretty, encoding: .utf8)
        {
            return text
        }
        return String(data: data, encoding: .utf8) ?? "<\(data.count) bytes>"
    }

    private static let redactedKeys: Set<String> = ["access", "refresh", "token", "password"]

    private static func redact(_ value: Any) -> Any {
        if let dict = value as? [String: Any] {
            return dict.reduce(into: [String: Any]()) { result, pair in
                result[pair.key] = redactedKeys.contains(pair.key.lowercased()) ? "<redacted>" : redact(pair.value)
            }
        }
        if let array = value as? [Any] {
            return array.map(redact)
        }
        return value
    }

    /// Unified logging truncates long messages, so a dump is written in chunks that stay readable.
    private static func emit(_ text: String) {
        let limit = 900
        var remaining = Substring(text)
        var part = 1
        while !remaining.isEmpty {
            let chunk = remaining.prefix(limit)
            remaining = remaining.dropFirst(chunk.count)
            let label = part == 1 && remaining.isEmpty ? "" : " [\(part)]"
            Log.network.debug("\(label, privacy: .public)\n\(String(chunk), privacy: .public)")
            part += 1
        }
    }
}
