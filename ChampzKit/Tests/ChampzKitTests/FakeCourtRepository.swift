import Foundation
@testable import ChampzKit

/// Scripted `CourtRepository`.
actor FakeCourtRepository: CourtRepository {
    enum Call: Equatable {
        case venue, durations, grid(String), courts(String, Int), book(PurchasePaymentMethod, key: String)
        case booking, accept(PurchasePaymentMethod, key: String), decline
    }

    private(set) var calls: [Call] = []
    private(set) var lastBody: BookingBody?
    /// What `GET /bookings/{id}/` answers; an invite for user "7" by default.
    var bookingJSON = inviteBookingJSON(answer: "pending", payable: "30.00")

    func set(bookingJSON: String) {
        self.bookingJSON = bookingJSON
    }

    func booking(_: BookingID) async throws(AppError) -> CourtBooking {
        calls.append(.booking)
        return .decode(bookingJSON)
    }

    func acceptInvite(_: BookingID, method: PurchasePaymentMethod, idempotencyKey: String)
        async throws(AppError) -> BookingParticipant
    {
        calls.append(.accept(method, key: idempotencyKey))
        return .decode(#"{"id": "row2", "user_id": "7", "invite_response_status": "accepted"}"#)
    }

    func declineInvite(_: BookingID) async throws(AppError) -> BookingParticipant {
        calls.append(.decline)
        return .decode(#"{"id": "row2", "user_id": "7", "invite_response_status": "declined"}"#)
    }

    var gridJSON = #"{"is_holiday": false, "slots": {"available_slots": ["#
        + #"{"start": "18:00", "end": "18:30", "available_durations": [60, 90]}, "#
        + #"{"start": "19:00", "end": "19:30", "available_durations": [60]}], "#
        + #""booked_slots": [{"start": "17:00", "end": "17:30", "available_durations": []}]}}"#
    var courtsJSON = #"{"is_holiday": false, "courts": ["#
        + #"{"id": "c1", "name": "Court 1", "court_type": "Indoor", "price": "150.00"}, "#
        + #"{"id": "c2", "name": "Court 2", "court_type": "Grass", "price": "180.00"}]}"#

    func venues(search _: String, surface _: String?) async throws(AppError) -> [Venue] {
        [testVenue]
    }

    func venue(_: VenueID) async throws(AppError) -> Venue {
        calls.append(.venue)
        return testVenue
    }

    func durations(_: VenueID) async throws(AppError) -> [Int] {
        calls.append(.durations)
        return [60, 90, 120]
    }

    func availability(_: VenueID, day: Date, availableOnly _: Bool) async throws(AppError) -> AvailabilityGrid {
        calls.append(.grid(day.apiDay))
        return .decode(gridJSON)
    }

    func courts(_: VenueID, day _: Date, start: String, duration: Int) async throws(AppError) -> CourtsForWindow {
        calls.append(.courts(start, duration))
        return .decode(courtsJSON)
    }

    func book(_ draft: CourtBookingDraft, method: PurchasePaymentMethod, me: PlayerID, idempotencyKey: String)
        async throws(AppError) -> CourtBooking
    {
        calls.append(.book(method, key: idempotencyKey))
        lastBody = BookingBody(draft, method: method, me: me)
        return testBooking(paid: method != .online)
    }
}

/// A split booking hosted by "host" with me (user "7", the fake account) invited.
func inviteBookingJSON(answer: String, payable: String) -> String {
    #"{"id": "b9", "unique_id": "CRT-000500", "court_name": "Court 1", "venue_name": "Aspire Courts", "#
        + #""date": "2026-10-09", "start_time": "18:00:00", "end_time": "19:00:00", "duration": 60, "#
        + #""payment_type": "split", "gross_price": "90.00", "service_fee": "5.00", "payable_amount": "\#(payable)", "#
        + #""owner": {"id": "row1", "user_id": "host", "name": "Omar Ali", "is_owner": true, "amount_due": "30.00"}, "#
        + #""participants": [{"id": "row1", "user_id": "host", "name": "Omar Ali", "is_owner": true}, "#
        + #"{"id": "row2", "user_id": "7", "name": "Anas E", "is_owner": false, "amount_due": "30.00", "#
        + #""invite_response_status": "\#(answer)"}]}"#
}

let testVenue = Venue.decode(
    #"{"id": "v1", "name": "Aspire Courts", "location": "Al Waab", "latitude": "25.26", "longitude": "51.44", "#
        + #""image_url": "https://cdn/x.jpg", "images": [], "no_of_courts": 2, "#
        + #""courts": [{"id": "c1", "name": "Court 1", "court_type": "Indoor", "#
        + #""slots": [{"lowest_price": "180.00"}, {"lowest_price": "150.00"}]}]}"#
)

func testBooking(paid: Bool) -> CourtBooking {
    .decode(
        #"{"id": "b1", "unique_id": "CRT-000412", "court_name": "Court 1", "venue_name": "Aspire Courts", "#
            + #""date": "2026-10-08", "start_time": "18:00:00", "end_time": "19:30:00", "duration": 90, "#
            + #""payment_type": "split", "gross_price": "100.00", "service_fee": "5.00", "#
            + #""payment_status": "\#(paid ? "partial" : "unpaid")", "payable_amount": "\#(paid ? "0.00" : "38.34")", "#
            + #""owner": {"id": "p1", "name": "Anas E", "is_owner": true, "amount_due": "33.34"}, "participants": []}"#
    )
}
