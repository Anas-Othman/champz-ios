import Foundation

/// Endpoints under /api/v1/wallet/. The balance itself is `PaymentRepository.wallet()`,
/// which checkout already uses.
enum WalletAPI {
    static func transactions(cursor: String?) -> Endpoint<CursorPage<LedgerEntry>> {
        Endpoint(.get, "/api/v1/wallet/transactions/").query(["limit": "20", "cursor": cursor])
    }

    static func topupBonus(_ amount: Money) -> Endpoint<TopupBonus> {
        Endpoint(.get, "/api/v1/wallet/topup/bonus-preview/").query(["amount": amount.apiString])
    }
}

public protocol WalletRepository: Sendable {
    func transactions(cursor: String?) async throws(AppError) -> CursorPage<LedgerEntry>
    func topupBonus(_ amount: Money) async throws(AppError) -> TopupBonus
}

public struct LiveWalletRepository: WalletRepository {
    let http: any HTTPClientProtocol

    public init(http: any HTTPClientProtocol) {
        self.http = http
    }

    public func transactions(cursor: String?) async throws(AppError) -> CursorPage<LedgerEntry> {
        try await http.send(WalletAPI.transactions(cursor: cursor))
    }

    public func topupBonus(_ amount: Money) async throws(AppError) -> TopupBonus {
        try await http.send(WalletAPI.topupBonus(amount))
    }
}
