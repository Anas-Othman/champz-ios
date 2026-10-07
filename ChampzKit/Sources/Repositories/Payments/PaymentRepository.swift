import Foundation

public protocol PaymentRepository: Sendable {
    func wallet() async throws(AppError) -> Wallet
    func splitPreview(_ purpose: PaymentPurpose, useWallet: Bool) async throws(AppError) -> SplitPreview
    /// Creates the hosted card checkout. Reuse `idempotencyKey` when retrying the same attempt.
    func checkout(_ purpose: PaymentPurpose, useWallet: Bool, idempotencyKey: String) async throws(AppError) -> Payment
    func applePaySession(_ purpose: PaymentPurpose, useWallet: Bool, idempotencyKey: String) async throws(AppError)
        -> PaymentSession
    func payment(_ id: PaymentID) async throws(AppError) -> Payment
    func abandon(_ id: PaymentID) async throws(AppError) -> Payment
}

public struct LivePaymentRepository: PaymentRepository {
    let http: any HTTPClientProtocol

    public init(http: any HTTPClientProtocol) {
        self.http = http
    }

    public func wallet() async throws(AppError) -> Wallet {
        try await http.send(PaymentsAPI.wallet())
    }

    public func splitPreview(_ purpose: PaymentPurpose, useWallet: Bool) async throws(AppError) -> SplitPreview {
        try await http.send(PaymentsAPI.splitPreview(purpose, useWallet: useWallet))
    }

    public func checkout(
        _ purpose: PaymentPurpose,
        useWallet: Bool,
        idempotencyKey: String
    ) async throws(AppError) -> Payment {
        try await http.send(PaymentsAPI.checkout(purpose, useWallet: useWallet, idempotencyKey: idempotencyKey))
    }

    public func applePaySession(
        _ purpose: PaymentPurpose,
        useWallet: Bool,
        idempotencyKey: String
    ) async throws(AppError) -> PaymentSession {
        try await http.send(PaymentsAPI.applePaySession(purpose, useWallet: useWallet, idempotencyKey: idempotencyKey))
    }

    public func payment(_ id: PaymentID) async throws(AppError) -> Payment {
        try await http.send(PaymentsAPI.payment(id))
    }

    public func abandon(_ id: PaymentID) async throws(AppError) -> Payment {
        try await http.send(PaymentsAPI.abandon(id))
    }
}
