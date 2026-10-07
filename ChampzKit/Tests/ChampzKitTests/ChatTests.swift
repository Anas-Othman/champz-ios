import Foundation
import Testing
@testable import ChampzKit

/// A chat whose live snapshots the test pushes by hand.
final class FakeChatRepository: ChatRepository, @unchecked Sendable {
    let stream: AsyncThrowingStream<[ChatMessage], any Error>
    let continuation: AsyncThrowingStream<[ChatMessage], any Error>.Continuation
    private(set) var sent: [ChatDraft] = []
    private(set) var reads = 0
    var olderPage: [ChatMessage] = []
    var failSend = false

    init() {
        (stream, continuation) = AsyncThrowingStream.makeStream()
    }

    var isAvailable: Bool {
        true
    }

    func latestMessages(_: MatchID, limit _: Int) -> AsyncThrowingStream<[ChatMessage], any Error> {
        stream
    }

    func messages(_: MatchID, before _: ChatMessage, limit _: Int) async throws -> [ChatMessage] {
        olderPage
    }

    func send(_ draft: ChatDraft, to _: MatchID) async throws {
        if failSend {
            throw AppError.offline
        }
        sent.append(draft)
    }

    func markRead(_: MatchID, by _: PlayerID) async {
        reads += 1
    }
}

func chatMessage(_ id: String, from sender: String, minute: Int) -> ChatMessage {
    ChatMessage(
        id: id, senderID: sender, senderName: "Player \(sender)", avatar: "", text: "Hi \(id)",
        createdAt: Date(timeIntervalSince1970: 1_800_000_000 + Double(minute) * 60)
    )
}

@MainActor
struct ChatViewModelTests {
    private func make(_ chat: some ChatRepository) -> ChatViewModel {
        ChatViewModel(
            matchID: MatchID("m1"), chat: chat, matches: PreviewMatchRepository(), profiles: FakeProfileRepository(),
            router: AppRouter(), toasts: ToastCenter()
        )
    }

    /// Starts `run()` and waits until the view model has handled `snapshots` snapshots.
    private func start(
        _ viewModel: ChatViewModel,
        _ chat: FakeChatRepository,
        pushing snapshots: [[ChatMessage]]
    ) async -> Task<Void, Never> {
        let task = Task { await viewModel.run() }
        for snapshot in snapshots {
            chat.continuation.yield(snapshot)
            for _ in 0 ..< 50
                where viewModel.phase != .ready || viewModel.messages.map(\.id) != snapshot.reversed().map(\.id)
            {
                try? await Task.sleep(for: .milliseconds(5))
            }
        }
        return task
    }

    /// Waits (up to ~1 s) for something the view model does right after a snapshot.
    private func eventually(_ condition: () -> Bool) async {
        for _ in 0 ..< 200 where !condition() {
            try? await Task.sleep(for: .milliseconds(5))
        }
    }

    @Test func withoutFirebaseTheChatSaysItIsUnavailable() async {
        let viewModel = make(UnavailableChatRepository())
        await viewModel.run()
        #expect(viewModel.phase == .unavailable)
    }

    @Test func liveSnapshotsShowOldestFirstAndMarkRead() async {
        let chat = FakeChatRepository()
        let viewModel = make(chat)
        let me = "01J9PLAYER0000000000000001" // the fake profile's id
        let task = await start(viewModel, chat, pushing: [
            [chatMessage("b", from: "42", minute: 2), chatMessage("a", from: me, minute: 1)],
        ])
        #expect(viewModel.phase == .ready)
        #expect(viewModel.messages.map(\.id) == ["a", "b"])
        #expect(viewModel.isMine(viewModel.messages[0]))
        #expect(!viewModel.isMine(viewModel.messages[1]))
        await eventually { chat.reads == 1 }
        #expect(chat.reads == 1) // read state follows every new message, not only opening
        task.cancel()
    }

    @Test func olderPagesJoinTheLiveWindowWithoutDuplicates() async {
        let chat = FakeChatRepository()
        chat.olderPage = [chatMessage("a", from: "42", minute: 1), chatMessage("z", from: "42", minute: 0)]
        let viewModel = make(chat)
        let task = await start(viewModel, chat, pushing: [
            [chatMessage("b", from: "42", minute: 2), chatMessage("a", from: "42", minute: 1)],
        ])
        await viewModel.loadOlder()
        #expect(viewModel.messages.map(\.id) == ["z", "a", "b"])
        #expect(viewModel.hasOlder == false) // a short page means the start of the chat
        task.cancel()
    }

    @Test func sendingCarriesMyIdentityAndAFailureGivesTheTextBack() async {
        let chat = FakeChatRepository()
        let viewModel = make(chat)
        let task = await start(viewModel, chat, pushing: [[]])
        viewModel.draft = "  See you at 6  "
        await viewModel.send()
        #expect(chat.sent.first?.text == "See you at 6")
        #expect(chat.sent.first?.senderID == PlayerID("01J9PLAYER0000000000000001")) // the ULID, not an int
        #expect(chat.sent.first?.senderName == "Anas E")
        #expect(viewModel.draft.isEmpty)

        chat.failSend = true
        viewModel.draft = "Late"
        await viewModel.send()
        #expect(viewModel.draft == "Late")
        task.cancel()
    }
}
