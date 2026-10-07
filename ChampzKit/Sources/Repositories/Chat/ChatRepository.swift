import Foundation

/// A match's group chat. The app implements it with Cloud Firestore (`FirestoreChatRepository`
/// in the app target); the package only knows this protocol, so it builds and tests without Firebase.
public protocol ChatRepository: Sendable {
    /// False when this build has no Firebase configuration: the chat screen says so instead of failing.
    var isAvailable: Bool { get }
    /// The newest `limit` messages, newest first, updated live while the stream is iterated.
    func latestMessages(_ match: MatchID, limit: Int) -> AsyncThrowingStream<[ChatMessage], any Error>
    /// The `limit` messages before `message`, newest first (scrolling up).
    func messages(_ match: MatchID, before message: ChatMessage, limit: Int) async throws -> [ChatMessage]
    func send(_ draft: ChatDraft, to match: MatchID) async throws
    /// Records that I have read up to now (`participants/{me}.last_read_at`).
    func markRead(_ match: MatchID, by player: PlayerID) async
}

/// Used when Firebase is not configured, and in previews.
public struct UnavailableChatRepository: ChatRepository {
    public init() {}

    public var isAvailable: Bool {
        false
    }

    public func latestMessages(_: MatchID, limit _: Int) -> AsyncThrowingStream<[ChatMessage], any Error> {
        AsyncThrowingStream { $0.finish() }
    }

    public func messages(_: MatchID, before _: ChatMessage, limit _: Int) async throws -> [ChatMessage] {
        []
    }

    public func send(_: ChatDraft, to _: MatchID) async throws {}
    public func markRead(_: MatchID, by _: PlayerID) async {}
}
