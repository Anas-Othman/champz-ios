import Foundation
import Observation

/// "Compete": a filtered list of tournaments, loaded a page at a time with a cursor.
@MainActor
@Observable
public final class TournamentsListViewModel {
    public private(set) var state: Loadable<[Tournament]> = .idle
    public private(set) var filter = TournamentFilter()
    public private(set) var isLoadingMore = false

    /// Empty when there is no next page.
    private var nextCursor = ""
    private let tournaments: any TournamentRepository
    private let router: AppRouter
    private let toasts: ToastCenter

    public init(tournaments: any TournamentRepository, router: AppRouter, toasts: ToastCenter) {
        self.tournaments = tournaments
        self.router = router
        self.toasts = toasts
    }

    public func load() async {
        guard case .idle = state else { return }
        state = .loading
        await fetchFirstPage()
    }

    /// Pull to refresh: keeps the current list on screen while reloading.
    public func refresh() async {
        await fetchFirstPage()
    }

    public func toggleThisWeek() async {
        await apply(TournamentFilter(thisWeek: !filter.thisWeek, kind: filter.kind))
    }

    /// Tapping the selected kind again clears it.
    public func toggle(_ kind: TournamentFilter.Kind) async {
        await apply(TournamentFilter(thisWeek: filter.thisWeek, kind: filter.kind == kind ? nil : kind))
    }

    /// Call from each row as it appears; only the last one loads the next page.
    public func loadMoreIfNeeded(after tournament: Tournament) async {
        guard !nextCursor.isEmpty, !isLoadingMore, case let .loaded(items) = state,
              items.last?.id == tournament.id else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await tournaments.tournaments(filter, cursor: nextCursor)
            nextCursor = page.nextCursor
            state = .loaded(items + page.items)
        } catch {
            toasts.show(error)
        }
    }

    public func open(_ tournament: Tournament) {
        router.push(.tournamentDetail(tournament.id))
    }

    private func apply(_ newFilter: TournamentFilter) async {
        filter = newFilter
        state = .loading
        await fetchFirstPage()
    }

    private func fetchFirstPage() async {
        do {
            let page = try await tournaments.tournaments(filter, cursor: nil)
            nextCursor = page.nextCursor
            state = .loaded(page.items)
        } catch {
            if case .loaded = state {
                toasts.show(error)
            } else {
                state = .failed(error)
            }
        }
    }
}
