import Foundation

enum HistoryAPI {
    /// Not paged: the server returns the whole list, sorted.
    static func history(_ filter: HistoryFilter) -> Endpoint<HistoryPage> {
        Endpoint(.get, "/api/v1/history/").query(filter.query)
    }
}

public protocol HistoryRepository: Sendable {
    func history(_ filter: HistoryFilter) async throws(AppError) -> [HistoryItem]
}

public struct LiveHistoryRepository: HistoryRepository {
    let http: any HTTPClientProtocol

    public init(http: any HTTPClientProtocol) {
        self.http = http
    }

    public func history(_ filter: HistoryFilter) async throws(AppError) -> [HistoryItem] {
        try await http.send(HistoryAPI.history(filter)).items
    }
}
