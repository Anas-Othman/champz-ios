import Foundation

/// Venue browsing (/api/v1/venues/) and booking (/api/v1/bookings/).
enum CourtsAPI {
    static func venues(search: String, surface: String?) -> Endpoint<[Venue]> {
        Endpoint(.get, "/api/v1/venues/").query([
            "search": search.trimmingCharacters(in: .whitespaces).isEmpty ? nil : search
                .trimmingCharacters(in: .whitespaces),
            "surface_type": surface,
        ])
    }

    static func venue(_ id: VenueID) -> Endpoint<Venue> {
        Endpoint(.get, "/api/v1/venues/\(id.raw)/")
    }

    static func durations(_ id: VenueID) -> Endpoint<VenueDurations> {
        Endpoint(.get, "/api/v1/venues/\(id.raw)/durations/")
    }

    static func availability(_ id: VenueID, day: Date, availableOnly: Bool) -> Endpoint<AvailabilityGrid> {
        Endpoint(.get, "/api/v1/venues/\(id.raw)/availability/").query([
            "date": day.apiDay,
            "available_only": availableOnly ? "true" : nil,
        ])
    }

    static func courts(_ id: VenueID, day: Date, start: String, duration: Int) -> Endpoint<CourtsForWindow> {
        Endpoint(.get, "/api/v1/venues/\(id.raw)/availability/").query([
            "date": day.apiDay,
            "start": String(start.prefix(5)),
            "duration": String(duration),
        ])
    }

    static func booking(_ id: BookingID) -> Endpoint<CourtBooking> {
        Endpoint(.get, "/api/v1/bookings/\(id.raw)/")
    }

    /// An invited player accepts and pays their share (card: settled by the checkout that follows).
    static func acceptInvite(
        _ id: BookingID,
        method: PurchasePaymentMethod,
        idempotencyKey: String
    ) -> Endpoint<BookingParticipant> {
        Endpoint(.post, "/api/v1/bookings/\(id.raw)/accept/", idempotencyKey: idempotencyKey)
            .json(["payment_method": method.rawValue])
    }

    static func declineInvite(_ id: BookingID) -> Endpoint<BookingParticipant> {
        Endpoint(.post, "/api/v1/bookings/\(id.raw)/decline/")
    }

    static func book(_ draft: CourtBookingDraft, method: PurchasePaymentMethod, me: PlayerID, idempotencyKey: String)
        -> Endpoint<CourtBooking>
    {
        Endpoint(.post, "/api/v1/bookings/", idempotencyKey: idempotencyKey)
            .json(BookingBody(draft, method: method, me: me))
    }
}

/// `POST /bookings/` body. No price and no end time: the server works both out.
struct BookingBody: Encodable {
    struct Participant: Encodable {
        let userId: String
        let isOwner: Bool
    }

    let courtId: String
    let date: String
    let startTime: String
    let duration: Int
    let paymentMethod: String
    let paymentType: String
    let participants: [Participant]
    let bookingName: String
    let bookingEmail: String
    let bookingCountryCode: String
    let bookingPhone: String

    init(_ draft: CourtBookingDraft, method: PurchasePaymentMethod, me: PlayerID) {
        courtId = draft.court.id.raw
        date = draft.day.apiDay
        startTime = String(draft.start.prefix(5))
        duration = draft.duration
        paymentMethod = method.rawValue
        paymentType = draft.isSplit ? "split" : "single"
        participants = [Participant(userId: me.raw, isOwner: true)]
            + draft.friends.map { Participant(userId: $0.id.raw, isOwner: false) }
        bookingName = draft.booking.trimmedName
        // The current app collected the email and never sent it.
        bookingEmail = draft.booking.trimmedEmail
        bookingCountryCode = draft.booking.country.dial
        bookingPhone = draft.booking.phone.trimmingCharacters(in: .whitespaces)
    }
}

public protocol CourtRepository: Sendable {
    func venues(search: String, surface: String?) async throws(AppError) -> [Venue]
    func venue(_ id: VenueID) async throws(AppError) -> Venue
    func durations(_ id: VenueID) async throws(AppError) -> [Int]
    func availability(_ id: VenueID, day: Date, availableOnly: Bool) async throws(AppError) -> AvailabilityGrid
    func courts(_ id: VenueID, day: Date, start: String, duration: Int) async throws(AppError) -> CourtsForWindow
    func booking(_ id: BookingID) async throws(AppError) -> CourtBooking
    func acceptInvite(_ id: BookingID, method: PurchasePaymentMethod, idempotencyKey: String)
        async throws(AppError) -> BookingParticipant
    func declineInvite(_ id: BookingID) async throws(AppError) -> BookingParticipant
    /// Books the court. `wallet`/`cash` complete here; `online` is unpaid until checkout settles.
    func book(_ draft: CourtBookingDraft, method: PurchasePaymentMethod, me: PlayerID, idempotencyKey: String)
        async throws(AppError) -> CourtBooking
}

public struct LiveCourtRepository: CourtRepository {
    let http: any HTTPClientProtocol

    public init(http: any HTTPClientProtocol) {
        self.http = http
    }

    public func venues(search: String, surface: String?) async throws(AppError) -> [Venue] {
        try await http.send(CourtsAPI.venues(search: search, surface: surface))
    }

    public func venue(_ id: VenueID) async throws(AppError) -> Venue {
        try await http.send(CourtsAPI.venue(id))
    }

    public func durations(_ id: VenueID) async throws(AppError) -> [Int] {
        try await http.send(CourtsAPI.durations(id)).durations.sorted()
    }

    public func availability(_ id: VenueID, day: Date, availableOnly: Bool) async throws(AppError) -> AvailabilityGrid {
        try await http.send(CourtsAPI.availability(id, day: day, availableOnly: availableOnly))
    }

    public func courts(
        _ id: VenueID,
        day: Date,
        start: String,
        duration: Int
    ) async throws(AppError) -> CourtsForWindow {
        try await http.send(CourtsAPI.courts(id, day: day, start: start, duration: duration))
    }

    public func book(
        _ draft: CourtBookingDraft,
        method: PurchasePaymentMethod,
        me: PlayerID,
        idempotencyKey: String
    ) async throws(AppError) -> CourtBooking {
        try await http.send(CourtsAPI.book(draft, method: method, me: me, idempotencyKey: idempotencyKey))
    }

    public func booking(_ id: BookingID) async throws(AppError) -> CourtBooking {
        try await http.send(CourtsAPI.booking(id))
    }

    public func acceptInvite(
        _ id: BookingID,
        method: PurchasePaymentMethod,
        idempotencyKey: String
    ) async throws(AppError) -> BookingParticipant {
        try await http.send(CourtsAPI.acceptInvite(id, method: method, idempotencyKey: idempotencyKey))
    }

    public func declineInvite(_ id: BookingID) async throws(AppError) -> BookingParticipant {
        try await http.send(CourtsAPI.declineInvite(id))
    }
}
