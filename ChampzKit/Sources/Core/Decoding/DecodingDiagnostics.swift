import Foundation

/// A field that decoded to a default because the server sent something unexpected.
/// `null` and absent keys are *not* issues (the defaults exist for them); a present
/// value of the wrong type or an unlisted enum case is.
public struct DecodingIssue: Sendable, Equatable {
    public let path: String
    public let detail: String

    public init(path: [CodingKey], detail: String) {
        self.path = path.map(\.stringValue).joined(separator: ".")
        self.detail = detail
    }
}

/// Collects lenient-decoding issues so they reach Sentry instead of disappearing.
/// The app installs a handler at startup; tests read `recent`.
public enum DecodingDiagnostics {
    private static let lock = NSLock()
    private nonisolated(unsafe) static var handler: (@Sendable (DecodingIssue) -> Void)?
    private nonisolated(unsafe) static var seen: Set<String> = []

    public static func install(_ newHandler: @escaping @Sendable (DecodingIssue) -> Void) {
        lock.withLock { handler = newHandler }
    }

    /// Reports each distinct path+detail once per process to avoid flooding.
    public static func report(_ issue: DecodingIssue) {
        let key = issue.path + "|" + issue.detail
        let handlerToCall: (@Sendable (DecodingIssue) -> Void)? = lock.withLock {
            guard seen.insert(key).inserted else { return nil }
            return handler
        }
        Log.decoding.warning("Lenient decode at \(issue.path, privacy: .public): \(issue.detail, privacy: .public)")
        handlerToCall?(issue)
    }

    /// Test hook: forget what was already reported.
    public static func reset() {
        lock.withLock { seen.removeAll() }
    }
}
