import Foundation

/// One message in a match's chat (`matches/{matchId}/messages/{id}` in Firestore).
public struct ChatMessage: Hashable, Sendable, Identifiable {
    public let id: String
    /// The sender's player id. New messages carry the ULID string; older ones from the
    /// current app carry a legacy integer, read here as its digits.
    public let senderID: String
    public let senderName: String
    public let avatar: String
    public let text: String
    /// Nil only for my own message until the server stamps it.
    public let createdAt: Date?

    public init(id: String, senderID: String, senderName: String, avatar: String, text: String, createdAt: Date?) {
        self.id = id
        self.senderID = senderID
        self.senderName = senderName
        self.avatar = avatar
        self.text = text
        self.createdAt = createdAt
    }

    /// "06:45 pm".
    public var timeText: String {
        guard let createdAt else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "hh:mm a"
        return formatter.string(from: createdAt).lowercased()
    }
}

/// What I send: the text, and who I am as other players will see it.
public struct ChatDraft: Hashable, Sendable {
    /// Firestore rules refuse anything longer.
    public static let maxLength = 2000

    public let senderID: PlayerID
    public let senderName: String
    public let avatar: String
    public let text: String
}
