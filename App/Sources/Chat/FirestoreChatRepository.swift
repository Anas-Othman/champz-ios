import ChampzKit
@preconcurrency import FirebaseFirestore
import Foundation

/// Match chat on Cloud Firestore, in the same layout the current app uses:
/// `matches/{matchId}/messages/{id}` and `matches/{matchId}/participants/{playerId}`.
///
/// No Firebase sign-in yet (parity with the current app): this works while the project's
/// rules allow unauthenticated access. When the backend ships `POST /auth/firebase-token/`,
/// sign in with the custom token here before the first read — nothing else changes.
struct FirestoreChatRepository: ChatRepository {
    var isAvailable: Bool {
        true
    }

    private func messages(_ match: MatchID) -> CollectionReference {
        Firestore.firestore().collection("matches").document(match.raw).collection("messages")
    }

    func latestMessages(_ match: MatchID, limit: Int) -> AsyncThrowingStream<[ChatMessage], any Error> {
        let query = messages(match).order(by: "created_at", descending: true).limit(to: limit)
        return AsyncThrowingStream { continuation in
            let registration = query.addSnapshotListener { snapshot, error in
                if let error {
                    continuation.finish(throwing: error)
                    return
                }
                continuation.yield(snapshot?.documents.compactMap(Self.message) ?? [])
            }
            let listener = Listener(registration)
            // Leaving the screen ends the stream, which removes the listener.
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    func messages(_ match: MatchID, before message: ChatMessage, limit: Int) async throws -> [ChatMessage] {
        guard let createdAt = message.createdAt else { return [] }
        let snapshot = try await messages(match)
            .order(by: "created_at", descending: true)
            .start(after: [Timestamp(date: createdAt)])
            .limit(to: limit)
            .getDocuments()
        return snapshot.documents.compactMap(Self.message)
    }

    func send(_ draft: ChatDraft, to match: MatchID) async throws {
        _ = try await messages(match).addDocument(data: [
            "sender_id": draft.senderID.raw,
            "sender_name": draft.senderName,
            "avatar": draft.avatar,
            "message": draft.text,
            "created_at": FieldValue.serverTimestamp(),
        ])
        await markRead(match, by: draft.senderID)
    }

    func markRead(_ match: MatchID, by player: PlayerID) async {
        try? await Firestore.firestore()
            .collection("matches").document(match.raw)
            .collection("participants").document(player.raw)
            .setData(["last_read_at": FieldValue.serverTimestamp()], merge: true)
    }

    /// A document to a message. `.estimate` gives my just-sent message a time before the server stamps it.
    /// `sender_id` is a ULID string from this app and a legacy integer from the current one.
    private static func message(_ document: QueryDocumentSnapshot) -> ChatMessage? {
        let data = document.data(with: .estimate)
        guard let text = data["message"] as? String else { return nil }
        let sender: String = switch data["sender_id"] {
        case let value as String: value
        case let value as NSNumber: value.stringValue
        default: ""
        }
        return ChatMessage(
            id: document.documentID,
            senderID: sender,
            senderName: data["sender_name"] as? String ?? "",
            avatar: data["avatar"] as? String ?? "",
            text: text,
            createdAt: (data["created_at"] as? Timestamp)?.dateValue()
        )
    }
}

/// Lets the stream's termination handler (which must be Sendable) remove the Firestore listener.
private final class Listener: @unchecked Sendable {
    private let registration: any ListenerRegistration

    init(_ registration: any ListenerRegistration) {
        self.registration = registration
    }

    func remove() {
        registration.remove()
    }
}
