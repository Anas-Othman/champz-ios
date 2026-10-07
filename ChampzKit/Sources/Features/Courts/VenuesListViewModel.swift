import Foundation
import Observation

/// "BOOK A COURT" (book_court_screen.dart): venues, searched by the server and filtered by surface.
@MainActor
@Observable
public final class VenuesListViewModel {
    /// The surface chips the backend understands (it expands each to its court types).
    public enum Surface: String, CaseIterable, Sendable {
        case indoor, grass, synthetic
    }

    public private(set) var state: Loadable<[Venue]> = .idle
    public private(set) var surface: Surface?
    public private(set) var search = ""
    private var generation = 0

    private let courts: any CourtRepository
    private let router: AppRouter
    private let toasts: ToastCenter

    public init(courts: any CourtRepository, router: AppRouter, toasts: ToastCenter) {
        self.courts = courts
        self.router = router
        self.toasts = toasts
    }

    public func load() async {
        guard case .idle = state else { return }
        state = .loading
        await reload()
    }

    /// The server searches name and location. (The current app filtered on the phone.)
    public func search(_ text: String) async {
        guard text != search else { return }
        search = text
        await reload()
    }

    /// Tapping the selected chip again clears it.
    public func toggle(_ chip: Surface) async {
        surface = surface == chip ? nil : chip
        state = .loading
        await reload()
    }

    public func reload() async {
        generation += 1
        let request = generation
        do {
            let venues = try await courts.venues(search: search, surface: surface?.rawValue)
            guard request == generation else { return }
            state = .loaded(venues)
        } catch {
            guard request == generation else { return }
            if case .loaded = state {
                toasts.show(error)
            } else {
                state = .failed(error)
            }
        }
    }

    public func open(_ venue: Venue) {
        router.push(.venueDetail(venue.id))
    }
}
