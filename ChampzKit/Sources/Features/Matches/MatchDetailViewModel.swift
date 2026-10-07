import Foundation
import Observation

/// One game: load it, and drive the bottom button (join / leave / waiting list).
@MainActor
@Observable
public final class MatchDetailViewModel {
    public let matchID: MatchID
    public private(set) var state: Loadable<Match> = .idle
    public private(set) var isWorking = false
    /// Reasons offered in the leave sheet; loaded when the sheet opens.
    public private(set) var leaveReasons: [LeaveReason] = []
    public var isLeaveSheetPresented = false

    private let matches: any MatchRepository
    private let router: AppRouter
    private let toasts: ToastCenter
    private let webURL: URL

    private let changes: DataChanges?

    public init(
        matchID: MatchID,
        matches: any MatchRepository,
        router: AppRouter,
        toasts: ToastCenter,
        webURL: URL,
        changes: DataChanges? = nil
    ) {
        self.changes = changes
        self.matchID = matchID
        self.matches = matches
        self.router = router
        self.toasts = toasts
        self.webURL = webURL
    }

    public var match: Match? {
        state.value
    }

    public func load() async {
        guard case .idle = state else { return }
        state = .loading
        await reload()
    }

    /// Coming back to the screen (after joining, leaving…): refresh quietly.
    public func refreshIfLoaded() {
        guard case .loaded = state else { return }
        Task { await reload() }
    }

    public func reload() async {
        do {
            state = try await .loaded(matches.match(matchID))
        } catch {
            if case .loaded = state {
                toasts.show(error)
            } else {
                state = .failed(error)
            }
        }
    }

    /// The big bottom button. Joining goes to the join flow; the rest happens here.
    public func primaryTapped() async {
        guard let match, !isWorking else { return }
        switch match.primaryAction {
        case .join:
            router.push(.joinMatch(match.id, waitingList: false))
        case .joinWaitingList:
            // Legacy behaviour: joining the waiting list goes through the same registration screen.
            router.push(.joinMatch(match.id, waitingList: true))
        case .leaveWaitingList:
            await perform { try await matches.leaveWaitingList(match.id) }
            changes?.matchesChanged()
        case .leave:
            await openLeaveSheet()
        case .full:
            break
        }
    }

    public func leave(reason: String) async {
        guard let match else { return }
        isLeaveSheetPresented = false
        await perform {
            let result = try await matches.leave(match.id, reason: reason)
            if let refunded = result.refunded, refunded > 0 {
                let amount = Money(refunded, currency: Money.defaultCurrency).compact
                toasts.show(Toast(.success, text: L10n.Matches.refundedToWallet(amount)))
            }
        }
        changes?.matchesChanged()
    }

    public func goBack() {
        router.goBack()
    }

    public func openTeamSheet() {
        router.push(.matchTeams(matchID))
    }

    public func openChat() {
        router.push(.chat(matchID))
    }

    public func openPlayer(_ player: MatchPlayer) {
        guard !player.playerId.isEmpty else { return }
        router.push(.playerProfile(PlayerID(player.playerId)))
    }

    /// The text shared from the detail screen, same wording as the current app.
    public var shareMessage: String? {
        guard let match else { return nil }
        return shareMessage(for: match)
    }

    public func shareMessage(for match: Match) -> String {
        let link = webURL.appending(queryItems: [URLQueryItem(name: "games_id", value: match.id.raw)]).absoluteString
        return L10n.Matches.shareMessage(match.title, match.kickoffDateText, match.kickoffTimeText, link)
    }

    // MARK: - Helpers

    private func openLeaveSheet() async {
        if leaveReasons.isEmpty {
            leaveReasons = await (try? matches.leaveReasons()) ?? []
        }
        isLeaveSheetPresented = true
    }

    /// Runs a mutation with the working flag, then reloads the match so the button reflects the server.
    private func perform(_ work: () async throws -> Void) async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await work()
            await reload()
        } catch let error as AppError {
            toasts.show(error)
        } catch {
            toasts.show(.unknown)
        }
    }
}
