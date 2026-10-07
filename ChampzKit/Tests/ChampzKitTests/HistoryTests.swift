import Foundation
import Testing
@testable import ChampzKit

/// Answers depend on the tab; records every filter asked for.
actor FakeHistoryRepository: HistoryRepository {
    private(set) var requests: [HistoryFilter] = []
    var delays: [HistoryFilter.Tab: Duration] = [:]

    func set(delay: Duration, for tab: HistoryFilter.Tab) {
        delays[tab] = delay
    }

    func history(_ filter: HistoryFilter) async throws(AppError) -> [HistoryItem] {
        requests.append(filter)
        if let delay = delays[filter.tab] {
            try? await Task.sleep(for: delay)
        }
        return filter.tab == .upcoming
            ? [historyItem(id: "m1", type: "match"), historyItem(id: "b1", type: "book_a_court")]
            : [historyItem(id: "t1", type: "tournament")]
    }
}

func historyItem(id: String, type: String) -> HistoryItem {
    .decode(
        #"{"id": "\#(id)", "type": "\#(type)", "name": "Court 1", "image": null, "date": "2026-10-07", "#
            + #""start_time": "18:00:00", "end_time": "19:30:00", "price": "55.00", "location": "Aspire Courts", "#
            + #""ground_name": "Aspire Zone", "total_player_count": 14, "joined_player_count": 12, "duration": 90, "#
            + #""surface_type": "Indoor", "payment_method": "wallet", "unique_id": "CRT-000412", "mode": null, "#
            + #""join_request": null}"#
    )
}

struct HistoryModelTests {
    @Test func eachKindOpensItsOwnScreen() {
        #expect(historyItem(id: "t1", type: "tournament").route == .tournamentDetail(TournamentID("t1")))
        #expect(historyItem(id: "m1", type: "match").route == .matchDetail(MatchID("m1")))
        // A round robin is a game, not a booking (the current app opened the booking receipt).
        #expect(historyItem(id: "r1", type: "round_robin").route == .matchDetail(MatchID("r1")))
        let booking = historyItem(id: "b1", type: "book_a_court")
        #expect(booking.route == .historyBooking(booking))
        #expect(historyItem(id: "x", type: "something_new").route == nil)
    }

    @Test func aBookingLeadsWithTheVenue() {
        let booking = historyItem(id: "b1", type: "book_a_court")
        #expect(booking.title == "Aspire Courts" && booking.venueText == "Aspire Courts")
        let game = historyItem(id: "m1", type: "match")
        #expect(game.title == "Court 1" && game.venueText == "Aspire Zone")
        #expect(game.whenText == "Wed, 07 October | 06:00 pm")
        #expect(game.priceMoney?.compact == "55 QR")
    }

    @Test func chipsMapToTheBackendParameters() {
        func query(_ filter: HistoryFilter) -> [String: String] {
            Dictionary(uniqueKeysWithValues: HistoryAPI.history(filter).query.map { ($0.name, $0.value ?? "") })
        }
        #expect(query(HistoryFilter()) == ["history_type": "upcoming"])
        #expect(query(HistoryFilter(tab: .previous, thisWeek: true, kind: .competitive))
            == ["history_type": "previous", "is_week": "true", "match_type": "1"])
        #expect(query(HistoryFilter(kind: .oneDay))["tournament_type"] == "1_day")
        #expect(query(HistoryFilter(kind: .league))["tournament_type"] == "1")
    }
}

@MainActor
struct HistoryViewModelTests {
    @Test func switchingTabsAsksAgainAndTheNewestAnswerWins() async {
        let repository = FakeHistoryRepository()
        await repository.set(delay: .milliseconds(150), for: .upcoming)
        let viewModel = HistoryViewModel(history: repository, router: AppRouter())
        // A slow Upcoming answer, then a quick switch to Previous.
        async let slow: Void = viewModel.load()
        try? await Task.sleep(for: .milliseconds(20))
        await viewModel.select(.previous)
        await slow
        #expect(viewModel.state.value?.map(\.id) == ["t1"]) // not overwritten by the late Upcoming answer
    }

    @Test func tappingTheSelectedChipClearsIt() async {
        let viewModel = HistoryViewModel(history: FakeHistoryRepository(), router: AppRouter())
        await viewModel.toggle(.friendly)
        #expect(viewModel.filter.kind == .friendly)
        await viewModel.toggle(.friendly)
        #expect(viewModel.filter.kind == nil)
    }

    @Test func openingAGamePushesTheMatch() {
        let router = AppRouter()
        let viewModel = HistoryViewModel(history: FakeHistoryRepository(), router: router)
        viewModel.open(historyItem(id: "m1", type: "match"))
        #expect(router.paths[.home]?.last == .matchDetail(MatchID("m1")))
    }
}
