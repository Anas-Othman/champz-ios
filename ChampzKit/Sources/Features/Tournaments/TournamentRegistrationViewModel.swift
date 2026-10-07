import Foundation
import Observation

/// "Confirm Registration" for a tournament: booking details and payment on one screen,
/// as in the current app. Paying is the shared `Checkout`; this type only knows how to
/// take a place and what to do once it is paid.
@MainActor
@Observable
public final class TournamentRegistrationViewModel: CheckoutOrder {
    public let tournament: Tournament
    public let checkout: Checkout
    public var booking = BookingInfo()
    public private(set) var errors: [BookingInfo.Field: String] = [:]

    private var joinRequest: JoinRequest?
    private var didPrefill = false
    private let tournaments: any TournamentRepository
    private let auth: any AuthRepository
    private let router: AppRouter
    private let changes: DataChanges?

    public init(
        tournament: Tournament,
        tournaments: any TournamentRepository,
        auth: any AuthRepository,
        payments: any PaymentRepository,
        content: any ContentRepository,
        router: AppRouter,
        toasts: ToastCenter,
        deviceSupportsApplePay: Bool = false,
        changes: DataChanges? = nil
    ) {
        self.tournament = tournament
        self.tournaments = tournaments
        self.auth = auth
        self.router = router
        self.changes = changes
        // No cash: the current app never offers it for tournaments.
        checkout = Checkout(
            price: tournament.joinPrice,
            allowsCash: false,
            deviceSupportsApplePay: deviceSupportsApplePay,
            payments: payments,
            content: content,
            toasts: toasts
        )
        checkout.order = self
    }

    /// Fills the booking fields from the account, once. If that fails the player types them.
    public func prefill() async {
        guard !didPrefill else { return }
        didPrefill = true
        if let user = try? await auth.currentUser() {
            booking = BookingInfo(user: user)
        }
    }

    public func inputChanged(_ field: BookingInfo.Field) {
        errors[field] = nil
    }

    // MARK: - CheckoutOrder

    public func validateOrder() -> Bool {
        errors = booking.validate()
        return errors.isEmpty
    }

    public func placeOrder(
        _ method: PurchasePaymentMethod,
        idempotencyKey: String
    ) async throws(AppError) -> PaymentPurpose {
        let request = try await tournaments.join(tournament.id, booking, method: method, idempotencyKey: idempotencyKey)
        joinRequest = request
        return .tournamentJoin(request.id)
    }

    public func orderPaid() {
        guard let joinRequest else { return }
        changes?.tournamentsChanged()
        router.push(.tournamentJoined(TournamentReceipt(tournament: tournament, joinRequest: joinRequest)))
    }

    /// Apple Pay went through but is not confirmed yet: back to the tournament, which shows the place once it settles.
    public func orderProcessing() {
        changes?.tournamentsChanged()
        router.popTo(.tournamentDetail(tournament.id))
    }
}
