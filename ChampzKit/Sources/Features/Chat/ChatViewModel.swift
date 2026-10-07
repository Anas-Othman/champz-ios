import Foundation
import Observation

/// The match chat (friendly_match_chat_screen.dart): the newest messages live, older ones
/// on scrolling up, and a box to send. Read state is updated on open and on every new message.
@MainActor
@Observable
public final class ChatViewModel {
    static let pageSize = 30

    public enum Phase: Equatable, Sendable {
        case loading, ready, unavailable
        case failed(String)
    }

    public let matchID: MatchID
    public private(set) var phase: Phase = .loading
    /// Oldest first, as shown.
    public private(set) var messages: [ChatMessage] = []
    public private(set) var match: Match?
    public var draft = ""
    public private(set) var isSending = false
    public private(set) var isLoadingOlder = false
    public private(set) var hasOlder = true

    private var live: [ChatMessage] = []
    private var older: [ChatMessage] = []
    private var me: PlayerProfile?

    private let chat: any ChatRepository
    private let matches: any MatchRepository
    private let profiles: any ProfileRepository
    private let router: AppRouter
    private let toasts: ToastCenter

    public init(
        matchID: MatchID,
        chat: any ChatRepository,
        matches: any MatchRepository,
        profiles: any ProfileRepository,
        router: AppRouter,
        toasts: ToastCenter
    ) {
        self.matchID = matchID
        self.chat = chat
        self.matches = matches
        self.profiles = profiles
        self.router = router
        self.toasts = toasts
    }

    public var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending && me != nil
    }

    public func isMine(_ message: ChatMessage) -> Bool {
        me.map { message.senderID == $0.id.raw } ?? false
    }

    /// Runs for as long as the screen is visible (call from `.task`); leaving cancels the listener.
    /// (The current app never cancelled its stream.)
    public func run() async {
        guard chat.isAvailable else {
            phase = .unavailable
            return
        }
        phase = .loading
        async let account = try? profiles.profile()
        async let header = try? matches.match(matchID)
        me = await account
        match = await header
        do {
            for try await latest in chat.latestMessages(matchID, limit: Self.pageSize) {
                live = latest
                rebuild()
                phase = .ready
                if let me {
                    await chat.markRead(matchID, by: me.id)
                }
            }
        } catch is CancellationError {
            return
        } catch {
            phase = .failed(String(localized: L10n.Chat.loadFailed))
        }
    }

    /// Scrolling reached the top: fetch the page before the oldest message shown.
    public func loadOlder() async {
        guard hasOlder, !isLoadingOlder, let oldest = messages.first else { return }
        isLoadingOlder = true
        defer { isLoadingOlder = false }
        do {
            let page = try await chat.messages(matchID, before: oldest, limit: Self.pageSize)
            hasOlder = page.count == Self.pageSize
            older += page
            rebuild()
        } catch {
            toasts.show(Toast(.error, L10n.Chat.loadFailed))
        }
    }

    public func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending, let me else { return }
        isSending = true
        defer { isSending = false }
        let message = ChatDraft(
            senderID: me.id,
            senderName: me.fullName,
            avatar: me.avatarUrl,
            text: String(text.prefix(ChatDraft.maxLength))
        )
        draft = ""
        do {
            try await chat.send(message, to: matchID)
        } catch {
            draft = text // give the text back so nothing is lost
            toasts.show(Toast(.error, L10n.Chat.sendFailed))
        }
    }

    public func openTeams() {
        router.push(.matchTeams(matchID))
    }

    /// Live window plus older pages, without duplicates, oldest first.
    private func rebuild() {
        var seen = Set<String>()
        messages = (live + older)
            .filter { seen.insert($0.id).inserted }
            .sorted { ($0.createdAt ?? .distantFuture) < ($1.createdAt ?? .distantFuture) }
    }
}
