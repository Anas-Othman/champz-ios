import Foundation

/// App-wide content: server settings, CMS pages, and the transfer-market search used to pick friends.
public protocol ContentRepository: Sendable {
    func settings() async throws(AppError) -> ServerSettings
    func cancellationPolicy() async throws(AppError) -> String
    func searchPlayers(_ query: String) async throws(AppError) -> [FriendCandidate]
}

public struct LiveContentRepository: ContentRepository {
    let http: any HTTPClientProtocol

    public init(http: any HTTPClientProtocol) {
        self.http = http
    }

    public func settings() async throws(AppError) -> ServerSettings {
        try await http.send(Endpoint(.get, "/api/v1/app-config/"))
    }

    public func cancellationPolicy() async throws(AppError) -> String {
        let page: PolicyPage = try await http.send(Endpoint(.get, "/api/v1/cms/pages/company_policy/"))
        return page.description
    }

    /// First 50 matches, newest sign-ups first; the server excludes the caller.
    public func searchPlayers(_ query: String) async throws(AppError) -> [FriendCandidate] {
        let endpoint = Endpoint<TransferMarketPage>(.get, "/api/v1/transfer-market/players/")
            .query(["limit": "50", "search": query.isEmpty ? nil : query])
        return try await http.send(endpoint).items
    }
}

/// `{items, next_cursor}`.
struct TransferMarketPage: Decodable, Sendable {
    @LossyArray var items: [FriendCandidate]
}
