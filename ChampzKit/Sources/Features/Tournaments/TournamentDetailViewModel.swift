import Foundation
import Observation

/// One tournament: load it, and drive the bottom button (join / leave).
/// Also backs the "Who's playing" screen, which shows the same data.
@MainActor
@Observable
public final class TournamentDetailViewModel {
    public let tournamentID: TournamentID
    public private(set) var state: Loadable<Tournament> = .idle
    public private(set) var isWorking = false
    public var isLeaveSheetPresented = false

    private let tournaments: any TournamentRepository
    private let router: AppRouter
    private let toasts: ToastCenter
    private let webURL: URL
    private let changes: DataChanges?

    public init(
        tournamentID: TournamentID,
        tournaments: any TournamentRepository,
        router: AppRouter,
        toasts: ToastCenter,
        webURL: URL,
        changes: DataChanges? = nil
    ) {
        self.tournamentID = tournamentID
        self.tournaments = tournaments
        self.router = router
        self.toasts = toasts
        self.webURL = webURL
        self.changes = changes
    }

    public var tournament: Tournament? {
        state.value
    }

    public func load() async {
        guard case .idle = state else { return }
        state = .loading
        await reload()
    }

    /// Something changed elsewhere (joined, left…): refresh quietly.
    public func refreshIfLoaded() {
        guard case .loaded = state else { return }
        Task { await reload() }
    }

    public func reload() async {
        do {
            state = try await .loaded(tournaments.tournament(tournamentID))
        } catch {
            if case .loaded = state {
                toasts.show(error)
            } else {
                state = .failed(error)
            }
        }
    }

    /// The big bottom button. Joining opens registration; leaving asks for a reason first.
    public func primaryTapped() {
        guard let tournament, !isWorking else { return }
        switch tournament.primaryAction {
        case .join: router.push(.joinTournament(tournament))
        case .leave: isLeaveSheetPresented = true
        case .full, .none: break
        }
    }

    public func leave(reason: String) async {
        isLeaveSheetPresented = false
        isWorking = true
        defer { isWorking = false }
        do {
            let result = try await tournaments.leave(tournamentID, reason: reason)
            if let refund = result.refund, refund > 0 {
                let amount = Money(refund, currency: Money.defaultCurrency).compact
                toasts.show(Toast(.success, text: L10n.Matches.refundedToWallet(amount)))
            }
            await reload()
            changes?.tournamentsChanged()
        } catch {
            toasts.show(error)
        }
    }

    public func goBack() {
        router.goBack()
    }

    public func openParticipants() {
        router.push(.tournamentParticipants(tournamentID))
    }

    public func openPlayer(_ player: TournamentPlayer) {
        router.push(.playerProfile(player.id))
    }

    public func openTeam(_ team: ClubBrief) {
        router.push(.teamDetail(team.id))
    }

    /// Same wording as matches; the link opens the tournament on the website.
    public var shareMessage: String? {
        tournament.map(shareMessage(for:))
    }

    public func shareMessage(for tournament: Tournament) -> String {
        let link = webURL.appending(queryItems: [URLQueryItem(name: "tournament_id", value: tournament.id.raw)])
        return L10n.Matches.shareMessage(
            tournament.name,
            tournament.startDayText,
            tournament.startTimeText,
            link.absoluteString
        )
    }
}
