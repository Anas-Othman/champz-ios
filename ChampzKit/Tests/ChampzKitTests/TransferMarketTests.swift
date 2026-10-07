import Foundation
import Testing
@testable import ChampzKit

/// Scripted `TransferMarketRepository`: answers depend on the filter's search text and the cursor.
actor FakeTransferMarketRepository: TransferMarketRepository {
    private(set) var requests: [(filter: MarketFilter, cursor: String?)] = []
    var topScorersFail = false

    func set(topScorersFail: Bool) {
        self.topScorersFail = topScorersFail
    }

    func players(_ filter: MarketFilter, cursor: String?) async throws(AppError) -> CursorPage<MarketPlayer> {
        requests.append((filter, cursor))
        if !filter.search.isEmpty {
            return marketPage(["found"], next: nil)
        }
        return cursor == nil ? marketPage(["a", "b"], next: "2") : marketPage(["c"], next: nil)
    }

    func topScorers() async throws(AppError) -> [MarketPlayer] {
        if topScorersFail {
            throw .server(message: nil, code: nil)
        }
        return [marketPlayer("star", goals: 40)]
    }
}

func marketPlayer(_ id: String, goals: Int = 3) -> MarketPlayer {
    .decode(
        #"{"id": "\#(id)", "full_name": "Player \#(id)", "avatar_url": "", "date_of_birth": "2000-01-15", "#
            + #""position": {"id": "p1", "name": "Striker"}, "nationality": null, "is_available": true, "#
            + #""club_name": null, "debut": null, "is_captain": false, "goals": \#(goals), "matches_played": 12}"#
    )
}

private func marketPage(_ ids: [String], next: String?) -> CursorPage<MarketPlayer> {
    let items = ids.map { #"{"id": "\#($0)", "full_name": "Player \#($0)", "goals": 1, "matches_played": 2}"# }
    return .decode(
        #"{"items": [\#(items.joined(separator: ","))], "next_cursor": \#(next.map { "\"\($0)\"" } ?? "null")}"#
    )
}

struct TransferMarketModelTests {
    @Test func marketCardReusesThePublicPlayer() throws {
        let player = marketPlayer("p7", goals: 12)
        #expect(player.id == PlayerID("p7"))
        #expect(player.player.fullName == "Player p7")
        #expect(player.goals == 12 && player.matchesPlayed == 12)
        let today = try #require(DateOfBirth.date(from: "2026-10-07"))
        #expect(player.player.age(on: today) == 26)
        #expect(player.positionAndAge.hasPrefix("Striker | Age "))
    }

    @Test func anEmptyFilterSendsNoFilters() {
        let query = Dictionary(uniqueKeysWithValues: TransferMarketAPI.players(MarketFilter(), cursor: nil).query
            .map { ($0.name, $0.value ?? "") })
        #expect(query == ["limit": "20"]) // no hidden 13–80 age range
    }

    @Test func filtersMapToTheBackendParameters() {
        let filter = MarketFilter(
            search: " omar ",
            position: .decode(#"{"id": "pos1", "name": "Goalkeeper"}"#),
            nationality: .decode(#"{"id": "c1", "code": "QA", "nationality": "Qatari"}"#),
            ages: 18 ... 30
        )
        let query = Dictionary(uniqueKeysWithValues: TransferMarketAPI.players(filter, cursor: "x").query
            .map { ($0.name, $0.value ?? "") })
        #expect(query == [
            "search": "omar", "position_id": "pos1", "nationality_id": "c1",
            "from_age": "18", "to_age": "30", "limit": "20", "cursor": "x",
        ])
        #expect(filter.activeCount == 3)
        #expect(filter.clearingSheetFilters() == MarketFilter(search: " omar "))
    }
}

@MainActor
struct TransferMarketViewModelTests {
    private func make(_ market: FakeTransferMarketRepository = FakeTransferMarketRepository())
        -> (TransferMarketViewModel, AppRouter)
    {
        let router = AppRouter()
        return (
            TransferMarketViewModel(
                market: market,
                profiles: FakeProfileRepository(),
                router: router,
                toasts: ToastCenter()
            ),
            router
        )
    }

    @Test func loadsBothSectionsAndPagesTheList() async {
        let market = FakeTransferMarketRepository()
        let (viewModel, _) = make(market)
        await viewModel.load()
        #expect(viewModel.topTalents.map(\.id.raw) == ["star"])
        let first = viewModel.talents.value ?? []
        await viewModel.loadMoreIfNeeded(after: first[1])
        #expect(viewModel.talents.value?.map(\.id.raw) == ["a", "b", "c"])
        #expect(await market.requests.map(\.cursor) == [nil, "2"])
    }

    @Test func clearingTheSearchBringsEveryoneBack() async {
        let (viewModel, _) = make()
        await viewModel.load()
        await viewModel.search("omar")
        #expect(viewModel.talents.value?.map(\.id.raw) == ["found"])
        await viewModel.search("")
        #expect(viewModel.talents.value?.map(\.id.raw) == ["a", "b"])
        #expect(viewModel.filter == MarketFilter())
    }

    @Test func topScorersFailingDoesNotHideTheList() async {
        let market = FakeTransferMarketRepository()
        await market.set(topScorersFail: true)
        let (viewModel, _) = make(market)
        await viewModel.load()
        #expect(viewModel.topTalents.isEmpty)
        #expect(viewModel.talents.value?.count == 2)
    }

    @Test func applyingTheSameFilterDoesNotRefetch() async {
        let market = FakeTransferMarketRepository()
        let (viewModel, _) = make(market)
        await viewModel.load()
        viewModel.openFilters()
        await viewModel.apply(MarketFilter())
        #expect(await market.requests.count == 1)
        #expect(viewModel.isFilterSheetPresented == false)
    }

    @Test func tappingAPlayerOpensTheirProfile() {
        let (viewModel, router) = make()
        viewModel.open(marketPlayer("p9"))
        #expect(router.paths[.home]?.last == .playerProfile(PlayerID("p9")))
    }
}
