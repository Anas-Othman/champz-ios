import Foundation

/// Everything the Matches and Home features need from the backend.
public protocol MatchRepository: Sendable {
    func matches(_ filter: MatchFilter, page: Page) async throws(AppError) -> PageResult<Match>
    func match(_ id: MatchID) async throws(AppError) -> Match
    func leaveReasons() async throws(AppError) -> [LeaveReason]
    /// Gives the spot up. The server applies the refund rule and returns what came back.
    func leave(_ id: MatchID, reason: String) async throws(AppError) -> LeaveResult
    func joinWaitingList(_ id: MatchID) async throws(AppError)
    func leaveWaitingList(_ id: MatchID) async throws(AppError)
    func home() async throws(AppError) -> HomeFeed
    /// Takes the spots. `wallet`/`cash` complete here; `online` is pending until checkout settles.
    func join(
        _ id: MatchID,
        _ draft: JoinDraft,
        method: PurchasePaymentMethod,
        idempotencyKey: String
    ) async throws(AppError) -> JoinRequest
}

public struct LiveMatchRepository: MatchRepository {
    let http: any HTTPClientProtocol

    public init(http: any HTTPClientProtocol) {
        self.http = http
    }

    public func matches(_ filter: MatchFilter, page: Page) async throws(AppError) -> PageResult<Match> {
        try await http.send(MatchesAPI.list(filter, page: page)).pageResult(for: page)
    }

    public func match(_ id: MatchID) async throws(AppError) -> Match {
        try await http.send(MatchesAPI.detail(id))
    }

    public func leaveReasons() async throws(AppError) -> [LeaveReason] {
        try await http.send(MatchesAPI.leaveReasons())
    }

    public func leave(_ id: MatchID, reason: String) async throws(AppError) -> LeaveResult {
        try await http.send(MatchesAPI.leave(id, reason: reason))
    }

    public func joinWaitingList(_ id: MatchID) async throws(AppError) {
        _ = try await http.send(MatchesAPI.joinWaitingList(id))
    }

    public func leaveWaitingList(_ id: MatchID) async throws(AppError) {
        _ = try await http.send(MatchesAPI.leaveWaitingList(id))
    }

    public func home() async throws(AppError) -> HomeFeed {
        try await http.send(MatchesAPI.home())
    }

    public func join(
        _ id: MatchID,
        _ draft: JoinDraft,
        method: PurchasePaymentMethod,
        idempotencyKey: String
    ) async throws(AppError) -> JoinRequest {
        try await http.send(MatchesAPI.join(id, draft, method: method, idempotencyKey: idempotencyKey))
    }
}
