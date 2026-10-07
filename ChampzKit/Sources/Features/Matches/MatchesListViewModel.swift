import Foundation
import Observation

/// "Find a match": a filtered, paginated list of games.
@MainActor
@Observable
public final class MatchesListViewModel {
    public private(set) var state: Loadable<[Match]> = .idle
    public private(set) var filter = MatchFilter.default
    public private(set) var isLoadingMore = false

    private var nextPage: Page?
    private let matches: any MatchRepository
    private let router: AppRouter
    private let toasts: ToastCenter

    public init(matches: any MatchRepository, router: AppRouter, toasts: ToastCenter) {
        self.matches = matches
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

    public func apply(_ newFilter: MatchFilter) async {
        guard newFilter != filter else { return }
        filter = newFilter
        state = .loading
        await fetchFirstPage()
    }

    /// Call from the last visible row; loads the next page once.
    public func loadMoreIfNeeded(after match: Match) async {
        guard let nextPage, !isLoadingMore, case let .loaded(items) = state, items.last?.id == match.id else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await matches.matches(filter, page: nextPage)
            self.nextPage = page.next
            state = .loaded(items + page.items)
        } catch {
            toasts.show(error)
        }
    }

    public func open(_ match: Match) {
        router.push(.matchDetail(match.id))
    }

    private func fetchFirstPage() async {
        do {
            let page = try await matches.matches(filter, page: .first)
            nextPage = page.next
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
