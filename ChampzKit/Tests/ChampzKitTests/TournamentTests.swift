import Foundation
import Testing
@testable import ChampzKit

/// Scripted `TournamentRepository` for view-model tests.
actor FakeTournamentRepository: TournamentRepository {
    enum Call: Equatable {
        case list(TournamentFilter, cursor: String?), detail(TournamentID), leave(TournamentID, String)
        case join(PurchasePaymentMethod, key: String)
    }

    private(set) var calls: [Call] = []
    /// Pages served in order: the first for `cursor == nil`, the next ones for each cursor.
    var pages: [CursorPage<Tournament>] = []
    var detail: Tournament = .preview

    func set(pages: [CursorPage<Tournament>]) {
        self.pages = pages
    }

    func set(detail: Tournament) {
        self.detail = detail
    }

    func tournaments(_ filter: TournamentFilter, cursor: String?) async throws(AppError) -> CursorPage<Tournament> {
        calls.append(.list(filter, cursor: cursor))
        let index = cursor.flatMap(Int.init) ?? 0
        guard index < pages.count else { throw .notFound }
        return pages[index]
    }

    func tournament(_ id: TournamentID) async throws(AppError) -> Tournament {
        calls.append(.detail(id))
        return detail
    }

    func leave(_ id: TournamentID, reason: String) async throws(AppError) -> TournamentLeaveResult {
        calls.append(.leave(id, reason))
        return .decode(#"{"refund": "40.00", "refund_percentage": "80.00"}"#)
    }

    func join(
        _: TournamentID,
        _: BookingInfo,
        method: PurchasePaymentMethod,
        idempotencyKey: String
    ) async throws(AppError) -> JoinRequest {
        calls.append(.join(method, key: idempotencyKey))
        return tournamentJoined
    }
}

/// A page of tournaments with the given ids; `next` is the cursor of the following page.
private func page(_ ids: [String], next: String?) -> CursorPage<Tournament> {
    let items = ids.map { #"{"id": "\#($0)", "joining_fee": "10.00"}"# }.joined(separator: ",")
    let cursor = next.map { "\"\($0)\"" } ?? "null"
    return .decode(#"{"items": [\#(items)], "next_cursor": \#(cursor)}"#)
}

struct TournamentModelTests {
    private func fixture() throws -> Tournament {
        let url = try #require(Bundle.module.url(
            forResource: "tournament_detail",
            withExtension: "json",
            subdirectory: "Fixtures"
        ))
        return try JSONDecoder.api().decode(Tournament.self, from: Data(contentsOf: url))
    }

    @Test func detailDecodesFromBackendShape() throws {
        let tournament = try fixture()
        #expect(tournament.format == .groupAndKnockout)
        #expect(tournament.type == .player)
        #expect(tournament.joiningFee == Decimal(string: "50.00"))
        #expect(tournament.prize?.compact == "500 QR")
        #expect(tournament.venueText == "Aspire Zone")
        #expect(tournament.ground?.coordinate?.latitude == 25.2635)
        #expect(tournament.joinPayerData.map(\.name) == ["Omar", "Ali"])
        #expect(tournament.joinTeamData.first?.name == "Falcons")
        #expect(tournament.totalPayers == 42)
    }

    @Test func listItemDecodesWithoutDetailFields() {
        let tournament = Tournament.decode(#"{"id": "t1", "name": "Cup", "joining_fee": "20.00", "ground": null}"#)
        #expect(tournament.venueText.isEmpty)
        #expect(tournament.days == nil)
        #expect(tournament.isAgeBlocked == false)
        #expect(tournament.primaryAction == .join)
    }

    @Test func missingFeeIsADecodingError() {
        #expect(throws: (any Error).self) {
            try JSONDecoder.api().decode(Tournament.self, from: Data(#"{"id": "t1"}"#.utf8))
        }
    }

    @Test func groupsHiddenWhenGroupSizeIsZero() throws {
        var tournament = try fixture()
        #expect(tournament.groupCount == nil)
        tournament.teamsPerGroup = 4
        #expect(tournament.groupCount == 2)
    }

    @Test func primaryActionFollowsServerFlags() throws {
        var tournament = try fixture()
        #expect(tournament.primaryAction == .leave)
        tournament.isLeaveTournament = false
        #expect(tournament.primaryAction == .none)
        tournament.joinStatus = 0
        #expect(tournament.primaryAction == .join)
        tournament.slotStatus = 1
        #expect(tournament.primaryAction == .full)
        tournament.slotStatus = 0
        tournament.isAgeEligible = false
        #expect(tournament.primaryAction == .none)
    }

    @Test func datesFormatLikeTheCurrentApp() throws {
        let tournament = try fixture()
        #expect(tournament.cardDateText == "Thu, 05 November | 06:00 pm")
        #expect(tournament.startDayText == "Thu, 5 Nov")
        #expect(tournament.endTimeText == "10:00 pm")
        #expect(tournament.isSingleDay == false)
        #expect(tournament.teamSizeText == "5 V 5")
    }

    @Test func homeFeedCarriesTournaments() {
        let feed = HomeFeed.decode(#"{"tournaments": [{"id": "t1", "joining_fee": "10.00"}]}"#)
        #expect(feed.tournaments.map(\.id.raw) == ["t1"])
    }

    @Test func listQuerySendsCursorAndFilters() {
        let endpoint = TournamentsAPI.list(TournamentFilter(kind: .oneDay), cursor: "abc")
        let query = Dictionary(uniqueKeysWithValues: endpoint.query.map { ($0.name, $0.value ?? "") })
        #expect(query == ["limit": "20", "cursor": "abc", "tournament_type": "1_day"])

        let week = TournamentsAPI.list(TournamentFilter(thisWeek: true), cursor: nil)
        #expect(week.query.map(\.name).sorted() == ["date_from", "date_to", "limit"])
    }
}

@MainActor
struct TournamentViewModelTests {
    @Test func listPagesWithTheCursor() async throws {
        let repository = FakeTournamentRepository()
        await repository.set(pages: [page(["a", "b"], next: "1"), page(["c"], next: nil)])
        let viewModel = TournamentsListViewModel(tournaments: repository, router: AppRouter(), toasts: ToastCenter())

        await viewModel.load()
        #expect(viewModel.state.value?.map(\.id.raw) == ["a", "b"])

        // Only the last row triggers the next page.
        try await viewModel.loadMoreIfNeeded(after: #require(viewModel.state.value?[0]))
        try await viewModel.loadMoreIfNeeded(after: #require(viewModel.state.value?[1]))
        #expect(viewModel.state.value?.map(\.id.raw) == ["a", "b", "c"])

        // No cursor left: nothing more is requested.
        try await viewModel.loadMoreIfNeeded(after: #require(viewModel.state.value?[2]))
        #expect(await repository.calls.count == 2)
    }

    @Test func tappingTheSelectedKindClearsIt() async {
        let repository = FakeTournamentRepository()
        await repository.set(pages: [page(["a"], next: nil)])
        let viewModel = TournamentsListViewModel(tournaments: repository, router: AppRouter(), toasts: ToastCenter())

        await viewModel.toggle(.knockout)
        #expect(viewModel.filter.kind == .knockout)
        await viewModel.toggle(.knockout)
        #expect(viewModel.filter.kind == nil)
        await viewModel.toggleThisWeek()
        #expect(viewModel.filter == TournamentFilter(thisWeek: true))
    }

    @Test func leavingReloadsAndSignalsOtherScreens() async throws {
        var joined = Tournament.preview
        joined.joinStatus = 1
        joined.isLeaveTournament = true
        let repository = FakeTournamentRepository()
        await repository.set(detail: joined)
        let changes = DataChanges()
        let toasts = ToastCenter()
        let viewModel = try TournamentDetailViewModel(
            tournamentID: joined.id,
            tournaments: repository,
            router: AppRouter(),
            toasts: toasts,
            webURL: #require(URL(string: "https://champz.me")),
            changes: changes
        )
        await viewModel.load()

        viewModel.primaryTapped()
        #expect(viewModel.isLeaveSheetPresented)

        await viewModel.leave(reason: "Injury")
        #expect(await repository.calls == [.detail(joined.id), .leave(joined.id, "Injury"), .detail(joined.id)])
        #expect(changes.tournamentsVersion == 1)
        #expect(viewModel.isLeaveSheetPresented == false)
    }

    @Test func joinOpensRegistration() async throws {
        let router = AppRouter()
        let viewModel = try TournamentDetailViewModel(
            tournamentID: Tournament.preview.id,
            tournaments: FakeTournamentRepository(),
            router: router,
            toasts: ToastCenter(),
            webURL: #require(URL(string: "https://champz.me"))
        )
        await viewModel.load()
        viewModel.primaryTapped()
        #expect(router.paths[.home]?.last == .joinTournament(.preview))
    }
}
