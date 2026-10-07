import Foundation
import Observation

/// "BOOKING SUMMARY" for joining a match. Paying is the shared `Checkout`;
/// this type only knows how to place a join and what to do when it is paid.
@MainActor
@Observable
public final class JoinConfirmViewModel: CheckoutOrder {
    public let draft: JoinDraft
    public let checkout: Checkout
    private var joinRequest: JoinRequest?
    private let changes: DataChanges?

    private let matches: any MatchRepository
    private let router: AppRouter

    public init(
        draft: JoinDraft,
        matches: any MatchRepository,
        payments: any PaymentRepository,
        content: any ContentRepository,
        router: AppRouter,
        toasts: ToastCenter,
        deviceSupportsApplePay: Bool = false,
        changes: DataChanges? = nil
    ) {
        self.changes = changes
        self.draft = draft
        self.matches = matches
        self.router = router
        checkout = Checkout(
            price: draft.price,
            allowsCash: true,
            deviceSupportsApplePay: deviceSupportsApplePay,
            payments: payments,
            content: content,
            toasts: toasts
        )
        checkout.order = self
    }

    public func placeOrder(
        _ method: PurchasePaymentMethod,
        idempotencyKey: String
    ) async throws(AppError) -> PaymentPurpose {
        let request = try await matches.join(draft.match.id, draft, method: method, idempotencyKey: idempotencyKey)
        joinRequest = request
        return .friendlyGameJoin(request.id)
    }

    /// Apple Pay went through but is not confirmed yet: back to the match, which will show the join once it settles.
    public func orderProcessing() {
        changes?.matchesChanged()
        router.popTo(.matchDetail(draft.match.id))
    }

    public func orderPaid() {
        guard let joinRequest else { return }
        changes?.matchesChanged()
        router.push(.joinDone(JoinReceipt(match: draft.match, joinRequest: joinRequest)))
    }
}
