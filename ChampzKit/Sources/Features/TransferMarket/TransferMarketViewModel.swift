import Foundation
import Observation

/// The Transfer Market tab (transfer_screen.dart): "Our Top Talents" (top scorers, never filtered)
/// and "Our Talents" (everyone, searchable, filterable, paged).
@MainActor
@Observable
public final class TransferMarketViewModel {
    public private(set) var talents: Loadable<[MarketPlayer]> = .idle
    public private(set) var topTalents: [MarketPlayer] = []
    public private(set) var filter = MarketFilter()
    public private(set) var isLoadingMore = false
    /// A new search or filter is loading while the old results stay on screen.
    public private(set) var isRefreshing = false

    // The filter sheet's pick lists, loaded the first time it opens.
    public private(set) var positions: [Position] = []
    public private(set) var nationalities: [Nationality] = []
    public var isFilterSheetPresented = false

    private var nextCursor = ""
    /// Only the newest request may write results, so a slow old search never
    /// overwrites a newer one. (The current app dropped a search typed while another ran.)
    private var generation = 0

    private let market: any TransferMarketRepository
    private let profiles: any ProfileRepository
    private let router: AppRouter
    private let toasts: ToastCenter

    public init(
        market: any TransferMarketRepository,
        profiles: any ProfileRepository,
        router: AppRouter,
        toasts: ToastCenter
    ) {
        self.market = market
        self.profiles = profiles
        self.router = router
        self.toasts = toasts
    }

    public func load() async {
        guard case .idle = talents else { return }
        talents = .loading
        await refresh()
    }

    /// Both sections, independently: one failing does not hide the other. Filters are kept.
    public func refresh() async {
        async let top: Void = loadTopTalents()
        async let list: Void = fetchFirstPage()
        _ = await (top, list)
    }

    /// From the search field, after typing pauses.
    public func search(_ text: String) async {
        guard text != filter.search else { return }
        var updated = filter
        updated.search = text
        await apply(updated)
    }

    public func apply(_ newFilter: MarketFilter) async {
        isFilterSheetPresented = false
        guard newFilter != filter else { return }
        filter = newFilter
        await fetchFirstPage()
    }

    /// Call from each row as it appears; only the last one loads the next page.
    public func loadMoreIfNeeded(after player: MarketPlayer) async {
        guard !nextCursor.isEmpty, !isLoadingMore, case let .loaded(items) = talents,
              items.last?.id == player.id else { return }
        let request = generation
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await market.players(filter, cursor: nextCursor)
            guard request == generation else { return }
            nextCursor = page.nextCursor
            talents = .loaded(items + page.items)
        } catch {
            toasts.show(error)
        }
    }

    public func openFilters() {
        isFilterSheetPresented = true
        guard positions.isEmpty || nationalities.isEmpty else { return }
        Task {
            async let positions = try? profiles.positions()
            async let nationalities = try? profiles.nationalities()
            self.positions = await positions ?? []
            self.nationalities = await nationalities ?? []
        }
    }

    public func open(_ player: MarketPlayer) {
        router.push(.playerProfile(player.id))
    }

    public func openNotifications() {
        router.push(.notifications)
    }

    // MARK: - Helpers

    private func loadTopTalents() async {
        // Secondary: if it fails the section is simply not shown.
        topTalents = await (try? market.topScorers()) ?? topTalents
    }

    private func fetchFirstPage() async {
        generation += 1
        let request = generation
        isRefreshing = talents.value != nil
        defer {
            if request == generation {
                isRefreshing = false
            }
        }
        do {
            let page = try await market.players(filter, cursor: nil)
            guard request == generation else { return }
            nextCursor = page.nextCursor
            talents = .loaded(page.items)
        } catch {
            guard request == generation else { return }
            if case .loaded = talents {
                toasts.show(error)
            } else {
                talents = .failed(error)
            }
        }
    }
}
