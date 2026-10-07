import Foundation
import Testing
@testable import ChampzKit

let tournamentJoined = JoinRequest.decode(
    #"{"id": "tjr1", "unique_id": "Champz-000777", "payment_status": "completed", "#
        + #""amount": "48.00", "service_fee": "2.00", "charge": "50.00"}"#
)

struct TournamentPricingTests {
    @Test func serviceFeeIsInsideTheJoiningFee() {
        var tournament = Tournament.preview
        tournament.serviceFee = 2
        #expect(tournament.joinPrice.subtotal.amount == 48)
        #expect(tournament.joinPrice.fee.amount == 2)
        #expect(tournament.joinPrice.total.amount == 50)
    }

    @Test func feeNeverExceedsTheJoiningFee() {
        var free = Tournament.preview
        free.joiningFee = 0
        free.serviceFee = 5
        #expect(free.joinPrice.total.isZero)
        #expect(free.joinPrice.fee.isZero)
    }

    @Test func joinBodyRegistersAsAnIndividual() throws {
        let data = try JSONEncoder.api().encode(TournamentJoinBody(testBooking, method: .wallet))
        let body = try #require(JSONSerialization.jsonObject(with: data) as? [String: String])
        #expect(body == [
            "payment_method": "wallet",
            "booking_name": "Anas",
            "booking_email": "a@b.co",
            "booking_mobile_no": "+974 55551234",
        ])
    }
}

@MainActor
struct TournamentRegistrationTests {
    private struct Harness {
        let viewModel: TournamentRegistrationViewModel
        let tournaments: FakeTournamentRepository
        let payments: FakePaymentRepository
        let router: AppRouter
        let changes: DataChanges
    }

    private func make(balance: Decimal = 0) async -> Harness {
        var tournament = Tournament.preview
        tournament.serviceFee = 2
        let tournaments = FakeTournamentRepository()
        let payments = FakePaymentRepository()
        await payments.set(balance: balance)
        let router = AppRouter()
        let changes = DataChanges()
        let viewModel = TournamentRegistrationViewModel(
            tournament: tournament,
            tournaments: tournaments,
            auth: FakeAuthRepository(),
            payments: payments,
            content: FakeContentRepository(),
            router: router,
            toasts: ToastCenter(),
            changes: changes
        )
        await viewModel.checkout.load()
        viewModel.checkout.pollInterval = .zero
        return Harness(
            viewModel: viewModel,
            tournaments: tournaments,
            payments: payments,
            router: router,
            changes: changes
        )
    }

    private func joins(_ repository: FakeTournamentRepository) async -> [PurchasePaymentMethod] {
        await repository.calls.compactMap {
            if case let .join(method, _) = $0 {
                method
            } else {
                nil
            }
        }
    }

    @Test func prefillsFromTheAccountAndBlocksPayingUntilTheFormIsValid() async {
        let harness = await make(balance: 100)
        await harness.viewModel.prefill()
        #expect(harness.viewModel.booking.name == "Anas E")

        // The account has no email: nothing is sent, the field says why.
        harness.viewModel.checkout.useWallet = true
        await harness.viewModel.checkout.pay()
        #expect(await joins(harness.tournaments).isEmpty)
        #expect(harness.viewModel.errors[.email] != nil)
    }

    @Test func cashIsNeverOffered() async {
        let harness = await make()
        #expect(harness.viewModel.checkout.isCashAvailable == false)
    }

    @Test func totalIsTheJoiningFee() async {
        let harness = await make()
        #expect(harness.viewModel.checkout.total.amount == 50)
    }

    @Test func walletCoveringTheFeeJoinsAndShowsTheTicket() async {
        let harness = await make(balance: 100)
        harness.viewModel.booking = testBooking
        harness.viewModel.checkout.useWallet = true
        await harness.viewModel.checkout.pay()
        #expect(await joins(harness.tournaments) == [.wallet])
        let receipt = TournamentReceipt(tournament: harness.viewModel.tournament, joinRequest: tournamentJoined)
        #expect(harness.router.paths[.home]?.last == .tournamentJoined(receipt))
        #expect(harness.changes.tournamentsVersion == 1)
    }

    @Test func cardPaysForTheTournamentJoin() async {
        let harness = await make()
        harness.viewModel.booking = testBooking
        await harness.viewModel.checkout.pay()
        #expect(await joins(harness.tournaments) == [.online])
        #expect(await harness.payments.lastPurpose == .tournamentJoin(tournamentJoined.id))

        await harness.viewModel.checkout
            .checkoutFinished(callback: URL(string: "champz://payment/callback?status=paid"))
        #expect(harness.router.paths[.home]?.last?.isTournamentJoined == true)
    }

    @Test func retryAfterAnErrorReusesTheSameJoin() async {
        let harness = await make()
        harness.viewModel.booking = testBooking
        await harness.payments.set(checkout: .failure(.offline))
        await harness.viewModel.checkout.pay()
        await harness.payments.set(checkout: .success(
            .decode(#"{"id": "pay1", "status": "pending", "pay_url": "https://pay.skipcash.app/x", "amount": "50.00"}"#)
        ))
        await harness.viewModel.checkout.pay()
        let keys = await harness.tournaments.calls.compactMap {
            if case let .join(_, key) = $0 {
                key
            } else {
                nil
            }
        }
        #expect(keys.count == 1)
    }
}

private extension AppRoute {
    var isTournamentJoined: Bool {
        if case .tournamentJoined = self {
            true
        } else {
            false
        }
    }
}
