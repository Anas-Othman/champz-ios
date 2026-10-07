import Foundation

/// Endpoints under /api/v1/transfer-market/.
enum TransferMarketAPI {
    static func players(_ filter: MarketFilter, cursor: String?) -> Endpoint<CursorPage<MarketPlayer>> {
        var query = filter.query
        query["limit"] = "20"
        query["cursor"] = cursor
        return Endpoint(.get, "/api/v1/transfer-market/players/").query(query)
    }

    /// At most ten, ranked by goals; not paged and not filtered.
    static func topScorers() -> Endpoint<[MarketPlayer]> {
        Endpoint(.get, "/api/v1/transfer-market/top-scorers/")
    }
}

public protocol TransferMarketRepository: Sendable {
    func players(_ filter: MarketFilter, cursor: String?) async throws(AppError) -> CursorPage<MarketPlayer>
    func topScorers() async throws(AppError) -> [MarketPlayer]
}

public struct LiveTransferMarketRepository: TransferMarketRepository {
    let http: any HTTPClientProtocol

    public init(http: any HTTPClientProtocol) {
        self.http = http
    }

    public func players(_ filter: MarketFilter, cursor: String?) async throws(AppError) -> CursorPage<MarketPlayer> {
        try await http.send(TransferMarketAPI.players(filter, cursor: cursor))
    }

    public func topScorers() async throws(AppError) -> [MarketPlayer] {
        try await http.send(TransferMarketAPI.topScorers())
    }
}
