import Foundation
import Testing
@testable import ChampzKit

/// Scripted `NotificationRepository`.
actor FakeNotificationRepository: NotificationRepository {
    private(set) var markedRead: [NotificationID?] = []
    private(set) var cursors: [String?] = []
    var unread = 3
    var failMarkAll = false

    func set(failMarkAll: Bool) {
        self.failMarkAll = failMarkAll
    }

    func notifications(cursor: String?) async throws(AppError) -> CursorPage<AppNotification> {
        cursors.append(cursor)
        if cursor == nil {
            let items = [
                notificationJSON(id: "n1", type: 4, status: 0, read: false, extra: #""booking_id": "b9""#),
                notificationJSON(id: "n2", type: 5, status: 1, read: false, extra: #""match_id": "m1""#),
            ]
            return .decode(#"{"items": [\#(items.joined(separator: ","))], "next_cursor": "2"}"#)
        }
        let last = notificationJSON(id: "n3", type: 1, status: 0, read: true, extra: #""actor_id": "p5""#)
        return .decode(#"{"items": [\#(last)], "next_cursor": null}"#)
    }

    func markRead(_ id: NotificationID?) async throws(AppError) {
        if id == nil, failMarkAll {
            throw .offline
        }
        markedRead.append(id)
    }

    func unreadCount() async throws(AppError) -> Int {
        unread
    }

    private(set) var registeredTokens: [String] = []

    func registerDevice(token: String) async throws(AppError) {
        registeredTokens.append(token)
    }
}

func notificationJSON(id: String, type: Int, status: Int, read: Bool, extra: String) -> String {
    #"{"id": "\#(id)", "title": "", "message": "Hello \#(id)", "notify_type": \#(type), "status": \#(status), "#
        + #""is_read": \#(read), "created_at": "2026-10-07T10:00:00Z", \#(extra)}"#
}

struct NotificationModelTests {
    @Test func eachKindOpensWhereItBelongs() {
        let invite = AppNotification.decode(notificationJSON(
            id: "a",
            type: 4,
            status: 0,
            read: false,
            extra: #""booking_id": "b1""#
        ))
        #expect(invite.isOpenBookingInvite)
        #expect(invite.target == .bookingInvite(BookingID("b1")))

        let tournament = AppNotification.decode(notificationJSON(
            id: "b", type: 0, status: 3, read: true, extra: #""tournament_id": "t1", "match_id": "m1""#
        ))
        #expect(tournament.target == .tournamentDetail(TournamentID("t1")))

        let game = AppNotification.decode(notificationJSON(
            id: "c",
            type: 5,
            status: 1,
            read: true,
            extra: #""match_id": "m1""#
        ))
        #expect(game.target == .matchDetail(MatchID("m1")))

        let offer = AppNotification.decode(notificationJSON(
            id: "d",
            type: 2,
            status: 0,
            read: false,
            extra: #""actor_id": "p5""#
        ))
        #expect(offer.target == .playerProfile(PlayerID("p5"))) // shown, not answered, for now
        #expect(!offer.isOpenBookingInvite)

        let unknown = AppNotification.decode(notificationJSON(
            id: "e",
            type: 9,
            status: 7,
            read: false,
            extra: #""match_id": null"#
        ))
        #expect(unknown.notifyType == .unknown && unknown.target == nil)
    }

    @Test func markAllSendsNoID() throws {
        let data = try #require(NotificationsAPI.markRead(nil).body)
        #expect(String(bytes: data, encoding: .utf8) == #"{"notification_id":null}"#)
    }
}

@MainActor
struct NotificationsViewModelTests {
    private struct Harness {
        let viewModel: NotificationsViewModel
        let repository: FakeNotificationRepository
        let courts: FakeCourtRepository
        let router: AppRouter
    }

    private func make() -> Harness {
        let repository = FakeNotificationRepository()
        let courts = FakeCourtRepository()
        let router = AppRouter()
        let viewModel = NotificationsViewModel(
            notifications: repository,
            courts: courts,
            router: router,
            toasts: ToastCenter()
        )
        return Harness(viewModel: viewModel, repository: repository, courts: courts, router: router)
    }

    @Test func pagesWithTheCursor() async throws {
        let harness = make()
        let (viewModel, repository) = (harness.viewModel, harness.repository)
        await viewModel.load()
        try await viewModel.loadMoreIfNeeded(after: #require(viewModel.state.value?[1]))
        #expect(viewModel.state.value?.map(\.id.raw) == ["n1", "n2", "n3"])
        #expect(await repository.cursors == [nil, "2"])
    }

    @Test func openingMarksReadAndRoutes() async throws {
        let harness = make()
        let (viewModel, repository, router) = (harness.viewModel, harness.repository, harness.router)
        await viewModel.load()
        try viewModel.open(#require(viewModel.state.value?[1]))
        #expect(viewModel.state.value?[1].isRead == true) // at once, before the server answers
        #expect(router.paths[.home]?.last == .matchDetail(MatchID("m1")))
        try? await Task.sleep(for: .milliseconds(50))
        #expect(await repository.markedRead == [NotificationID("n2")])
    }

    @Test func markAllComesBackIfTheServerRefuses() async {
        let harness = make()
        let (viewModel, repository) = (harness.viewModel, harness.repository)
        await repository.set(failMarkAll: true)
        await viewModel.load()
        await viewModel.markAllRead()
        #expect(viewModel.hasUnread) // dots restored
    }

    @Test func declineAsksFirstThenHidesTheButtons() async throws {
        let harness = make()
        let (viewModel, courts) = (harness.viewModel, harness.courts)
        await viewModel.load()
        let invite = try #require(viewModel.state.value?[0])
        #expect(viewModel.showsInviteButtons(invite))
        viewModel.askToDecline(invite)
        #expect(await courts.calls.isEmpty) // nothing sent before confirming
        await viewModel.confirmDecline()
        #expect(await courts.calls == [.decline])
        #expect(!viewModel.showsInviteButtons(invite))
    }

    @Test func badgeReadsTheServerCount() async {
        let badge = NotificationBadge(notifications: FakeNotificationRepository())
        await badge.refresh()
        #expect(badge.count == 3)
    }
}

@MainActor
struct BookingInviteViewModelTests {
    private struct Harness {
        let viewModel: BookingInviteViewModel
        let courts: FakeCourtRepository
        let payments: FakePaymentRepository
        let router: AppRouter
    }

    private func make(_ json: String) async -> Harness {
        let courts = FakeCourtRepository()
        await courts.set(bookingJSON: json)
        let payments = FakePaymentRepository()
        await payments.set(balance: 100)
        let router = AppRouter()
        let viewModel = BookingInviteViewModel(
            bookingID: BookingID("b9"), courts: courts, auth: FakeAuthRepository(), payments: payments,
            content: FakeContentRepository(), router: router, toasts: ToastCenter()
        )
        await viewModel.checkout.load()
        await viewModel.load()
        viewModel.checkout.pollInterval = .zero
        return Harness(viewModel: viewModel, courts: courts, payments: payments, router: router)
    }

    @Test func anOpenInviteChargesTheServersShareWithNoFee() async {
        let viewModel = await make(inviteBookingJSON(answer: "pending", payable: "30.00")).viewModel
        #expect(viewModel.state.value?.answer == .open)
        #expect(viewModel.checkout.total.amount == 30)
    }

    @Test func payingByWalletAcceptsOnceAndShowsTheTicket() async {
        let harness = await make(inviteBookingJSON(answer: "pending", payable: "30.00"))
        let (viewModel, courts, router) = (harness.viewModel, harness.courts, harness.router)
        viewModel.checkout.useWallet = true
        await viewModel.checkout.pay()
        let accepts = await courts.calls.filter {
            if case .accept = $0 {
                true
            } else {
                false
            }
        }
        #expect(accepts.count == 1)
        guard case let .bookingInviteAccepted(receipt) = router.paths[.home]?.last else {
            Issue.record("Expected the ticket")
            return
        }
        #expect(receipt.paid.amount == 30 && receipt.booking.uniqueId == "CRT-000500")
    }

    @Test func cardAcceptThenPaysForTheBooking() async {
        let harness = await make(inviteBookingJSON(answer: "pending", payable: "30.00"))
        let (viewModel, payments) = (harness.viewModel, harness.payments)
        await viewModel.checkout.pay()
        #expect(await payments.lastPurpose == .courtBooking(BookingID("b9")))
    }

    @Test func answeredInvitesOfferNoPayment() async {
        #expect(await make(inviteBookingJSON(answer: "accepted", payable: "0.00")).viewModel.state.value?
            .answer == .accepted)
        #expect(await make(inviteBookingJSON(answer: "declined", payable: "30.00")).viewModel.state.value?
            .answer == .declined)
    }
}
