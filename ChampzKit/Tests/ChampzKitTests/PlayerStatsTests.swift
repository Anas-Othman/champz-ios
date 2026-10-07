import Foundation
import Testing
@testable import ChampzKit

struct PlayerStatsModelTests {
    @Test func decodesTheBackendShape() {
        let stats = PlayerStats.preview
        #expect(stats.player.clubName == "Falcons")
        #expect(stats.player.nationality?.flag == "🇪🇬")
        #expect(stats.statistics.goalsTotal == 31)
        #expect(stats.statistics.transfers.first?.transferredTo == "Falcons")
        #expect(stats.player.debutText == "MAR, 2024")
    }

    @Test func missingSectionsDecodeAsEmpty() {
        let stats = PlayerStats.decode(
            #"{"player": {"id": "p9", "nationality": null, "position": null, "club_name": null, "debut": null}, "#
                + #""statistics": {"accolades": [], "transfers": null}}"#
        )
        #expect(stats.statistics.matchesPlayed == 0)
        #expect(stats.statistics.transfers.isEmpty)
        #expect(stats.player.debutText.isEmpty)
        #expect(stats.player.age() == nil) // no "Age 0"
    }

    @Test func ageIsWholeYears() throws {
        let today = try #require(DateOfBirth.date(from: "2026-03-06"))
        #expect(PlayerStats.preview.player.age(on: today) == 30) // born 1995-03-07, birthday tomorrow
    }

    @Test func statsEndpointTakesThePlayerID() {
        #expect(ProfileAPI.stats(PlayerID("p1")).path == "/api/v1/players/p1/stats/")
    }
}

@MainActor
struct PlayerStatsViewModelTests {
    @Test func myStatsAsksForMyOwnIDAndLoadsTheWallet() async {
        let profiles = FakeProfileRepository()
        let payments = FakePaymentRepository()
        await payments.set(balance: 120)
        let viewModel = MyStatsViewModel(
            profiles: profiles,
            payments: payments,
            router: AppRouter(),
            toasts: ToastCenter()
        )
        await viewModel.load()

        #expect(await profiles.statsRequests == [PlayerID("01J9PLAYER0000000000000001")])
        #expect(viewModel.state.value?.balance.amount == 120)
        #expect(viewModel.state.value?.stats == .preview)
    }

    @Test func editProfileOpensTheSheetAndTheAvatarOpensMyStats() {
        let router = AppRouter()
        let viewModel = MyStatsViewModel(
            profiles: FakeProfileRepository(),
            payments: FakePaymentRepository(),
            router: router,
            toasts: ToastCenter()
        )
        viewModel.editProfile()
        #expect(router.sheet == .editProfile)

        HomeViewModel(matches: FakeMatchRepository(), router: router, toasts: ToastCenter()).openProfile()
        #expect(router.selectedTab == .myStats)
    }

    @Test func anotherPlayersProfileLoadsTheirStats() async {
        let profiles = FakeProfileRepository()
        let viewModel = PlayerProfileViewModel(playerID: PlayerID("p42"), profiles: profiles, toasts: ToastCenter())
        await viewModel.load()
        #expect(await profiles.statsRequests == [PlayerID("p42")])
        #expect(viewModel.state.value == .preview)
    }

    @Test func unknownPlayerShowsNotFound() async {
        let profiles = FakeProfileRepository()
        await profiles.set(statsResult: .failure(.notFound))
        let viewModel = PlayerProfileViewModel(playerID: PlayerID("gone"), profiles: profiles, toasts: ToastCenter())
        await viewModel.load()
        #expect(viewModel.state.error == .notFound)
    }
}
