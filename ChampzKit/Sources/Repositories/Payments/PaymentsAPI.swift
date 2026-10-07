import Foundation

/// Endpoints under /api/v1/payments/ and /api/v1/wallet/.
enum PaymentsAPI {
    static func wallet() -> Endpoint<Wallet> {
        Endpoint(.get, "/api/v1/wallet/")
    }

    static func splitPreview(_ purpose: PaymentPurpose, useWallet: Bool) -> Endpoint<SplitPreview> {
        Endpoint(.post, "/api/v1/payments/split-preview/").json(CheckoutBody(purpose, useWallet: useWallet))
    }

    static func checkout(_ purpose: PaymentPurpose, useWallet: Bool, idempotencyKey: String) -> Endpoint<Payment> {
        Endpoint(.post, "/api/v1/payments/checkout/", idempotencyKey: idempotencyKey)
            .json(CheckoutBody(purpose, useWallet: useWallet))
    }

    /// Apple Pay: the server creates (or reuses a live) SkipCash SDK session for the card leg.
    static func applePaySession(
        _ purpose: PaymentPurpose,
        useWallet: Bool,
        idempotencyKey: String
    ) -> Endpoint<PaymentSession> {
        Endpoint(.post, "/api/v1/payments/sessions/", idempotencyKey: idempotencyKey)
            .json(CheckoutBody(purpose, useWallet: useWallet, extra: ["payment_method": "apple_pay"]))
    }

    static func payment(_ id: PaymentID) -> Endpoint<Payment> {
        Endpoint(.get, "/api/v1/payments/\(id.raw)/")
    }

    /// Player left the hosted page: refunds the wallet leg and releases the pending join unless the card cleared.
    static func abandon(_ id: PaymentID) -> Endpoint<Payment> {
        Endpoint(.post, "/api/v1/payments/\(id.raw)/abandon/")
    }
}

/// `{purpose, join_request_id, use_wallet, channel}`.
struct CheckoutBody: Encodable {
    let fields: [String: String]
    let useWallet: Bool

    init(_ purpose: PaymentPurpose, useWallet: Bool, extra: [String: String] = [:]) {
        fields = purpose.body.merging(["channel": "app"]) { $1 }.merging(extra) { $1 }
        self.useWallet = useWallet
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: AnyKey.self)
        for (key, value) in fields {
            try container.encode(value, forKey: AnyKey(key))
        }
        try container.encode(useWallet, forKey: AnyKey("use_wallet"))
    }

    private struct AnyKey: CodingKey {
        let stringValue: String
        var intValue: Int? {
            nil
        }

        init(_ string: String) {
            stringValue = string
        }

        init?(stringValue: String) {
            self.stringValue = stringValue
        }

        init?(intValue _: Int) {
            nil
        }
    }
}
