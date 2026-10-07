import Foundation
import Testing
@testable import ChampzKit

/// Scripted `MatchRepository` for view-model tests.
actor FakeMatchRepository: MatchRepository {
    enum Call: Equatable {
        case list(MatchFilter, Page), detail(MatchID), leaveReasons, leave(MatchID, String), joinWaiting(MatchID),
             leaveWaiting(MatchID), home
        case join(PurchasePaymentMethod, key: String)
    }

    private(set) var calls: [Call] = []
    var pages: [PageResult<Match>] = []
    var detail: Result<Match, AppError> = .success(.preview)
    var leaveResult: Result<LeaveResult, AppError> = .success(LeaveResult(refunded: 30, slotsFreed: 1))

    func set(pages: [PageResult<Match>]) {
        self.pages = pages
    }

    func set(detail: Result<Match, AppError>) {
        self.detail = detail
    }

    func set(leave: Result<LeaveResult, AppError>) {
        leaveResult = leave
    }

    func matches(_ filter: MatchFilter, page: Page) async throws(AppError) -> PageResult<Match> {
        calls.append(.list(filter, page))
        guard page.number - 1 < pages.count else { throw .notFound }
        return pages[page.number - 1]
    }

    func match(_ id: MatchID) async throws(AppError) -> Match {
        calls.append(.detail(id))
        return try detail.get()
    }

    func leaveReasons() async throws(AppError) -> [LeaveReason] {
        calls.append(.leaveReasons)
        return [LeaveReason(id: 1, reason: "Injury")]
    }

    func leave(_ id: MatchID, reason: String) async throws(AppError) -> LeaveResult {
        calls.append(.leave(id, reason))
        return try leaveResult.get()
    }

    func joinWaitingList(_ id: MatchID) async throws(AppError) {
        calls.append(.joinWaiting(id))
    }

    func leaveWaitingList(_ id: MatchID) async throws(AppError) {
        calls.append(.leaveWaiting(id))
    }

    func home() async throws(AppError) -> HomeFeed {
        calls.append(.home); throw .notFound
    }

    var joinResult: Result<JoinRequest, AppError> = .failure(.unknown)

    func set(join: Result<JoinRequest, AppError>) {
        joinResult = join
    }

    func join(
        _: MatchID,
        _: JoinDraft,
        method: PurchasePaymentMethod,
        idempotencyKey: String
    ) async throws(AppError) -> JoinRequest {
        calls.append(.join(method, key: idempotencyKey))
        return try joinResult.get()
    }
}

extension LeaveResult {
    init(refunded: Decimal?, slotsFreed: Int) {
        self.init()
        self.refunded = refunded
        self.slotsFreed = slotsFreed
    }

    init() {
        // swiftlint:disable:next force_try
        self = try! JSONDecoder.api().decode(LeaveResult.self, from: Data("{}".utf8))
    }
}

@MainActor
struct MatchesListViewModelTests {
    private func page(_ ids: [String], next: Page?) -> PageResult<Match> {
        PageResult(items: ids.map { id in
            var match = Match.preview
            match.id = MatchID(id)
            return match
        }, next: next, total: ids.count)
    }

    @Test func loadsFirstPageThenAppendsNext() async {
        let repo = FakeMatchRepository()
        await repo.set(pages: [page(["a", "b"], next: Page(number: 2)), page(["c"], next: nil)])
        let viewModel = MatchesListViewModel(matches: repo, router: AppRouter(), toasts: ToastCenter())

        await viewModel.load()
        var rows = viewModel.state.value ?? []
        #expect(rows.map(\.id.raw) == ["a", "b"])

        await viewModel.loadMoreIfNeeded(after: rows[0]) // not the last row: no call
        await viewModel.loadMoreIfNeeded(after: rows[1])
        rows = viewModel.state.value ?? []
        #expect(rows.map(\.id.raw) == ["a", "b", "c"])

        await viewModel.loadMoreIfNeeded(after: rows[2]) // no next page: no call
        #expect(await repo.calls.count == 2)
    }

    @Test func applyingAFilterReloadsFromPageOne() async {
        let repo = FakeMatchRepository()
        await repo.set(pages: [page(["a"], next: nil)])
        let viewModel = MatchesListViewModel(matches: repo, router: AppRouter(), toasts: ToastCenter())
        await viewModel.load()
        await viewModel.apply(MatchFilter(dates: .thisWeek))
        await viewModel.apply(MatchFilter(dates: .thisWeek)) // same filter: ignored
        #expect(await repo.calls == [.list(.default, .first), .list(MatchFilter(dates: .thisWeek), .first)])
    }

    @Test func failureOnFirstLoadIsAState() async {
        let viewModel = MatchesListViewModel(matches: FakeMatchRepository(), router: AppRouter(), toasts: ToastCenter())
        await viewModel.load()
        #expect(viewModel.state.error == .notFound)
    }

    @Test func openingAMatchPushesTheRoute() {
        let router = AppRouter()
        let viewModel = MatchesListViewModel(matches: FakeMatchRepository(), router: router, toasts: ToastCenter())
        viewModel.open(.preview)
        #expect(router.paths[.home] == [.matchDetail(Match.preview.id)])
    }
}

@MainActor
struct MatchDetailViewModelTests {
    private func make(
        _ repo: FakeMatchRepository,
        router: AppRouter = AppRouter(),
        toasts: ToastCenter = ToastCenter()
    ) -> MatchDetailViewModel {
        MatchDetailViewModel(
            matchID: Match.preview.id,
            matches: repo,
            router: router,
            toasts: toasts,
            webURL: URL(string: "https://champz.me")!
        )
    }

    @Test func joinGoesToTheJoinFlow() async {
        let router = AppRouter()
        let viewModel = make(FakeMatchRepository(), router: router)
        await viewModel.load()
        await viewModel.primaryTapped()
        #expect(router.paths[.home] == [.joinMatch(Match.preview.id, waitingList: false)])
    }

    @Test func leaveOpensSheetThenLeavesAndReloads() async {
        let repo = FakeMatchRepository()
        var joined = Match.preview
        joined.joinStatus = true
        await repo.set(detail: .success(joined))
        let toasts = ToastCenter()
        let viewModel = make(repo, toasts: toasts)
        await viewModel.load()

        await viewModel.primaryTapped()
        #expect(viewModel.isLeaveSheetPresented)
        #expect(viewModel.leaveReasons.map(\.reason) == ["Injury"])

        await viewModel.leave(reason: "Injury")
        #expect(!viewModel.isLeaveSheetPresented)
        #expect(toasts.current?.kind == .success)
        #expect(await repo.calls == [
            .detail(joined.id),
            .leaveReasons,
            .leave(joined.id, "Injury"),
            .detail(joined.id),
        ])
    }

    @Test func leaveWaitingListCallsTheAPIAndReloads() async {
        let repo = FakeMatchRepository()
        var waiting = Match.preview
        waiting.isJoinWaitingList = true
        await repo.set(detail: .success(waiting))
        let viewModel = make(repo)
        await viewModel.load()
        await viewModel.primaryTapped()
        #expect(await repo.calls == [.detail(waiting.id), .leaveWaiting(waiting.id), .detail(waiting.id)])
    }

    @Test func shareMessageCarriesTheWebLink() async {
        let viewModel = make(FakeMatchRepository())
        await viewModel.load()
        let message = viewModel.shareMessage ?? ""
        #expect(message.contains("https://champz.me?games_id=01J9MATCH0000000000000001"))
        #expect(message.contains("Friday Night 5s"))
    }
}
