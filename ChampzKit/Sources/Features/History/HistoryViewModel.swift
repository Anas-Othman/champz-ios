import Foundation
import Observation

/// "My History" (my_footchampz_history_screen.dart): my tournaments, games and bookings,
/// Upcoming or Previous, narrowed by the chips.
@MainActor
@Observable
public final class HistoryViewModel {
    public private(set) var state: Loadable<[HistoryItem]> = .idle
    public private(set) var filter = HistoryFilter()
    /// Only the newest request may write the list. (In the current app a quick tab tap
    /// could let an older answer overwrite a newer one.)
    private var generation = 0

    private let history: any HistoryRepository
    private let router: AppRouter

    public init(history: any HistoryRepository, router: AppRouter) {
        self.history = history
        self.router = router
    }

    public func load() async {
        guard case .idle = state else { return }
        await reload()
    }

    public func select(_ tab: HistoryFilter.Tab) async {
        guard tab != filter.tab else { return }
        filter.tab = tab
        await reload(showingLoading: true)
    }

    public func toggleThisWeek() async {
        filter.thisWeek.toggle()
        await reload(showingLoading: true)
    }

    /// Tapping the selected chip again clears it.
    public func toggle(_ kind: HistoryFilter.Kind) async {
        filter.kind = filter.kind == kind ? nil : kind
        await reload(showingLoading: true)
    }

    public func reload(showingLoading: Bool = false) async {
        generation += 1
        let request = generation
        if showingLoading || state.value == nil {
            state = .loading
        }
        do {
            let items = try await history.history(filter)
            guard request == generation else { return }
            state = .loaded(items)
        } catch {
            guard request == generation else { return }
            state = .failed(error)
        }
    }

    public func open(_ item: HistoryItem) {
        if let route = item.route {
            router.push(route)
        }
    }
}
