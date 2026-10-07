import Foundation
import Observation

/// The venue page (book_court_details_screen.dart): pick a day, a start, a duration and a court.
/// Each choice loads the next from the server; prices are the server's for that exact window.
@MainActor
@Observable
public final class VenueDetailViewModel {
    /// Bookable days: today and the next 30 (current app).
    public static let bookableDays = 31

    public let venueID: VenueID
    public private(set) var venue: Loadable<Venue> = .idle
    public private(set) var venueDurations: [Int] = []
    public let days: [Date]

    public private(set) var day: Date
    public var availableOnly = false {
        didSet {
            if availableOnly != oldValue {
                Task { await loadGrid() }
            }
        }
    }

    public private(set) var grid: Loadable<AvailabilityGrid> = .idle
    public private(set) var start: SlotStart?
    public private(set) var duration: Int?
    public private(set) var courts: Loadable<[PricedCourt]> = .idle
    public private(set) var court: PricedCourt?

    /// Bumped on every new question, so an old answer never overwrites a newer one.
    private var generation = 0
    private let repository: any CourtRepository
    private let router: AppRouter
    private let toasts: ToastCenter
    private let webURL: URL

    public init(
        venueID: VenueID,
        courts: any CourtRepository,
        router: AppRouter,
        toasts: ToastCenter,
        webURL: URL,
        today: Date = .now
    ) {
        self.venueID = venueID
        self.webURL = webURL
        repository = courts
        self.router = router
        self.toasts = toasts
        let calendar = Calendar.current
        let first = calendar.startOfDay(for: today)
        days = (0 ..< Self.bookableDays).compactMap { calendar.date(byAdding: .day, value: $0, to: first) }
        day = first
    }

    /// Venue and its durations together, then today's grid.
    public func load() async {
        guard case .idle = venue else { return }
        venue = .loading
        do {
            async let loaded = repository.venue(venueID)
            async let durations = try? repository.durations(venueID)
            venue = try await .loaded(loaded)
            venueDurations = await durations ?? []
        } catch let error as AppError {
            venue = .failed(error)
            return
        } catch {
            venue = .failed(.unknown)
            return
        }
        await loadGrid()
    }

    // MARK: - Choices

    public func select(day newDay: Date) async {
        guard newDay != day else { return }
        day = newDay
        await loadGrid()
    }

    public func select(start newStart: SlotStart) async {
        guard !newStart.isBooked, newStart != start else { return }
        start = newStart
        duration = durations(at: newStart).first
        await loadCourts()
    }

    public func select(duration newDuration: Int) async {
        guard newDuration != duration else { return }
        duration = newDuration
        await loadCourts()
    }

    public func select(court newCourt: PricedCourt) {
        court = newCourt
    }

    /// The durations this start offers, limited to what the venue sells.
    public func durations(at slot: SlotStart) -> [Int] {
        let offered = slot.availableDurations.sorted()
        guard !venueDurations.isEmpty else { return offered }
        return offered.filter(venueDurations.contains)
    }

    public var startDurations: [Int] {
        start.map(durations(at:)) ?? []
    }

    /// Book: carry the choice to the summary screen.
    public func book() {
        guard let venue = venue.value, let start, let duration else { return }
        guard let court else {
            toasts.show(Toast(.info, L10n.Courts.selectCourtFirst))
            return
        }
        router.push(.bookCourt(CourtBookingDraft(
            venue: venue,
            court: court,
            day: day,
            start: start.start,
            duration: duration
        )))
    }

    public func openInfo() {
        guard let venue = venue.value else { return }
        router.push(.venueInfo(venue))
    }

    /// The venue's page on the website, as the current app shares it.
    public var shareLink: URL {
        webURL.appending(queryItems: [URLQueryItem(name: "venue_id", value: venueID.raw)])
    }

    public func goBack() {
        router.goBack()
    }

    // MARK: - Loading

    /// A new day (or the available-only switch): fresh grid, first free start picked.
    func loadGrid() async {
        generation += 1
        let request = generation
        start = nil
        duration = nil
        court = nil
        courts = .idle
        grid = .loading
        do {
            let loaded = try await repository.availability(venueID, day: day, availableOnly: availableOnly)
            guard request == generation else { return }
            grid = .loaded(loaded)
            if let first = loaded.starts.first(where: { !$0.isBooked && !durations(at: $0).isEmpty }) {
                start = first
                duration = durations(at: first).first
                await loadCourts()
            }
        } catch {
            guard request == generation else { return }
            grid = .failed(error)
        }
    }

    /// A new start or duration: the courts free for exactly that window, with their prices.
    func loadCourts() async {
        guard let start, let duration else { return }
        generation += 1
        let request = generation
        court = nil
        courts = .loading
        do {
            let loaded = try await repository.courts(venueID, day: day, start: start.start, duration: duration)
            guard request == generation else { return }
            courts = .loaded(loaded.courts)
            // One court: pick it. Several: the player chooses.
            if loaded.courts.count == 1 {
                court = loaded.courts.first
            }
        } catch {
            guard request == generation else { return }
            courts = .failed(error)
        }
    }
}
