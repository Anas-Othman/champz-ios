import Foundation
import Testing
@testable import ChampzKit

private func draft(price: String = "100.00", friends: Int = 0) -> CourtBookingDraft {
    var draft = CourtBookingDraft(
        venue: testVenue,
        court: .decode(#"{"id": "c1", "name": "Court 1", "court_type": "Indoor", "price": "\#(price)"}"#),
        day: Calendar.current.startOfDay(for: .now),
        start: "18:00",
        duration: 90
    )
    draft.friends = (0 ..< friends).map { FriendCandidate.decode(#"{"id": "f\#($0)", "full_name": "Friend \#($0)"}"#) }
    draft.fee = Money(5, currency: "QAR")
    draft.booking = testBooking
    draft.hostID = PlayerID("me")
    return draft
}

struct CourtModelTests {
    @Test func venueCardShowsTheCheapestHourAndThePicture() {
        #expect(testVenue.startingPrice?.compact == "150 QR")
        #expect(testVenue.gallery == ["https://cdn/x.jpg"])
        #expect(abs((testVenue.coordinate?.latitude ?? 0) - 25.26) < 0.000_001)
    }

    @Test func gridMergesFreeAndTakenInTimeOrder() {
        let grid = AvailabilityGrid.decode(
            #"{"slots": {"available_slots": [{"start": "18:00", "available_durations": [60]}], "#
                + #""booked_slots": [{"start": "17:00", "available_durations": []}]}}"#
        )
        #expect(grid.starts.map(\.start) == ["17:00", "18:00"])
        #expect(grid.starts.map(\.isBooked) == [true, false])
        #expect(grid.starts[1].label == "06:00 pm")
        #expect(TimeOfDay.label("00:30") == "12:30 am")
    }

    @Test func splitMatchesTheServerRule() {
        // 100 / 3 = 33.33 each; the 0.01 left over goes on the host.
        let split = draft(friends: 2)
        #expect(split.isSplit)
        #expect(split.hostShare.amount == Decimal(string: "33.34"))
        #expect(split.friendShare.amount == Decimal(string: "33.33"))
        #expect(split.price.total.amount == Decimal(string: "38.34")) // share + fee

        let alone = draft()
        #expect(alone.hostShare.amount == 100)
        #expect(alone.price.total.amount == 105)
    }

    @Test func bookingBodyNamesTheHostFirstAndSendsNoPrice() throws {
        let body = BookingBody(draft(friends: 1), method: .wallet, me: PlayerID("me"))
        let data = try JSONEncoder.api().encode(body)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["payment_type"] as? String == "split")
        #expect(json["start_time"] as? String == "18:00")
        #expect(json["duration"] as? Int == 90)
        #expect(json["booking_email"] as? String == "a@b.co") // the current app never sent it
        #expect(json["price"] == nil)
        let participants = try #require(json["participants"] as? [[String: Any]])
        #expect(participants.first?["user_id"] as? String == "me")
        #expect(participants.first?["is_owner"] as? Bool == true)
        #expect(participants.count == 2)
    }

    @Test func apiDayIsTheLocalCalendarDay() throws {
        let midnight = Calendar.current.startOfDay(for: .now)
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: midnight)
        let expected = try String(
            format: "%04d-%02d-%02d",
            #require(parts.year),
            #require(parts.month),
            #require(parts.day)
        )
        #expect(midnight.apiDay == expected) // not the UTC day before
    }

    @Test func courtBookingPurposeNamesTheBooking() {
        #expect(PaymentPurpose.courtBooking(BookingID("b1")).body == ["purpose": "court_booking", "booking_id": "b1"])
        #expect(testBooking(paid: true).hostCharge.amount == Decimal(string: "38.34"))
    }
}

@MainActor
struct VenueDetailViewModelTests {
    private func make(_ repository: FakeCourtRepository = FakeCourtRepository()) -> (VenueDetailViewModel, AppRouter) {
        let router = AppRouter()
        let viewModel = VenueDetailViewModel(
            venueID: VenueID("v1"), courts: repository, router: router, toasts: ToastCenter(),
            webURL: URL(string: "https://champz.me")!
        )
        return (viewModel, router)
    }

    @Test func loadingPicksTheFirstFreeStartAndLoadsItsCourts() async {
        let repository = FakeCourtRepository()
        let (viewModel, _) = make(repository)
        await viewModel.load()
        #expect(viewModel.days.count == 31)
        #expect(viewModel.start?.start == "18:00") // 17:00 is booked
        #expect(viewModel.duration == 60)
        #expect(viewModel.startDurations == [60, 90])
        #expect(viewModel.courts.value?.count == 2)
        #expect(viewModel.court == nil) // two courts: the player chooses
        #expect(await repository.calls.last == .courts("18:00", 60))
    }

    @Test func changingDurationReloadsCourtsAndBookCarriesTheChoice() async throws {
        let (viewModel, router) = make()
        await viewModel.load()
        await viewModel.select(duration: 90)
        viewModel.book() // no court yet: nothing happens
        #expect(router.paths[.home] == nil || router.paths[.home]?.isEmpty == true)

        let court = try #require(viewModel.courts.value?[1])
        viewModel.select(court: court)
        viewModel.book()
        guard case let .bookCourt(draft) = router.paths[.home]?.last else {
            Issue.record("Expected the summary screen")
            return
        }
        #expect(draft.court.id == CourtID("c2") && draft.duration == 90 && draft.start == "18:00")
        #expect(viewModel.shareLink.absoluteString == "https://champz.me?venue_id=v1")
    }

    @Test func aBookedStartCannotBeChosen() async throws {
        let (viewModel, _) = make()
        await viewModel.load()
        let booked = try #require(viewModel.grid.value?.starts.first { $0.isBooked })
        await viewModel.select(start: booked)
        #expect(viewModel.start?.start == "18:00")
    }
}

@MainActor
struct CourtBookingFlowTests {
    @Test func summaryLoadsTheServerFeeAndWhoIAm() async {
        let router = AppRouter()
        let summary = CourtBookingSummaryViewModel(
            draft: draft(), auth: FakeAuthRepository(),
            content: FakeContentRepository(settingsJSON: #"{"book_of_court_fee": "7.50", "is_cash_enable": true}"#),
            router: router
        )
        await summary.load()
        #expect(summary.draft?.fee.amount == Decimal(string: "7.50")) // not the current app's 0
        #expect(summary.draft?.hostID == PlayerID("7"))

        summary.booking.email = "" // the fake account has none
        summary.continueTapped()
        #expect(summary.errors[.email] != nil)
        summary.booking = testBooking
        summary.continueTapped()
        #expect(router.paths[.home]?.last.map {
            if case .confirmCourtBooking = $0 {
                true
            } else {
                false
            }
        } == true)
    }

    private struct Harness {
        let viewModel: CourtBookingConfirmViewModel
        let courts: FakeCourtRepository
        let payments: FakePaymentRepository
        let router: AppRouter
        let changes: DataChanges
    }

    private func confirm(balance: Decimal = 500) async -> Harness {
        let courts = FakeCourtRepository()
        let payments = FakePaymentRepository()
        await payments.set(balance: balance)
        let router = AppRouter()
        let changes = DataChanges()
        let viewModel = CourtBookingConfirmViewModel(
            draft: draft(friends: 2), courts: courts, payments: payments, content: FakeContentRepository(),
            router: router, toasts: ToastCenter(), changes: changes
        )
        await viewModel.checkout.load()
        viewModel.checkout.pollInterval = .zero
        return Harness(viewModel: viewModel, courts: courts, payments: payments, router: router, changes: changes)
    }

    /// The payment methods `book` was called with, in order.
    private func bookings(_ courts: FakeCourtRepository) async -> [PurchasePaymentMethod] {
        await courts.calls.compactMap { call -> PurchasePaymentMethod? in
            if case let .book(method, _) = call {
                method
            } else {
                nil
            }
        }
    }

    @Test func walletBookingCompletesAndShowsTheTicket() async {
        let harness = await confirm()
        harness.viewModel.checkout.useWallet = true
        await harness.viewModel.checkout.pay()
        #expect(await bookings(harness.courts) == [.wallet])
        let receipt = CourtBookingReceipt(draft: harness.viewModel.draft, booking: testBooking(paid: true))
        #expect(harness.router.paths[.home]?.last == .courtBooked(receipt))
        #expect(harness.changes.walletVersion == 1)
    }

    @Test func cardPaysForTheBookingAndARetryReusesIt() async {
        let harness = await confirm(balance: 0)
        await harness.payments.set(checkout: .failure(.offline))
        await harness.viewModel.checkout.pay()
        await harness.payments.set(checkout: .success(
            .decode(#"{"id": "pay1", "status": "pending", "pay_url": "https://pay.skipcash.app/x", "amount": "38.34"}"#)
        ))
        await harness.viewModel.checkout.pay()
        #expect(await bookings(harness.courts) == [.online]) // one booking, not one per attempt
        #expect(await harness.payments.lastPurpose == .courtBooking(BookingID("b1")))
    }
}
