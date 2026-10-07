import Foundation
import Observation

/// An invite to share someone's court booking: the booking, my share, and pay or decline.
/// Paying is the shared `Checkout`; accepting is placed once per attempt with an idempotency key.
@MainActor
@Observable
public final class BookingInviteViewModel: CheckoutOrder {
    public enum Answer: Hashable, Sendable {
        /// Waiting for me: pay my share or decline.
        case open
        case accepted
        case declined
        /// I am not on this booking (any more).
        case notInvited
    }

    public struct Content: Hashable, Sendable {
        public let booking: CourtBooking
        public let answer: Answer
    }

    public let bookingID: BookingID
    public private(set) var state: Loadable<Content> = .idle
    public let checkout: Checkout
    public var isDeclineConfirmPresented = false
    public private(set) var isDeclining = false

    private let courts: any CourtRepository
    private let auth: any AuthRepository
    private let router: AppRouter
    private let toasts: ToastCenter
    private let changes: DataChanges?

    public init(
        bookingID: BookingID,
        courts: any CourtRepository,
        auth: any AuthRepository,
        payments: any PaymentRepository,
        content: any ContentRepository,
        router: AppRouter,
        toasts: ToastCenter,
        deviceSupportsApplePay: Bool = false,
        changes: DataChanges? = nil
    ) {
        self.bookingID = bookingID
        self.courts = courts
        self.auth = auth
        self.router = router
        self.toasts = toasts
        self.changes = changes
        checkout = Checkout(
            price: PriceBreakdown(subtotal: .zero(Money.defaultCurrency)),
            allowsCash: true, // only when the server's cash switch is on
            deviceSupportsApplePay: deviceSupportsApplePay,
            payments: payments,
            content: content,
            toasts: toasts
        )
        checkout.order = self
    }

    /// The booking and who I am together; my row on it decides what the screen offers.
    public func load() async {
        if case .loading = state {
            return
        }
        state = .loading
        do {
            async let booking = courts.booking(bookingID)
            async let me = auth.currentUser()
            let (loaded, account) = try await (booking, me)
            let row = loaded.participants.first { $0.userId == account.id.raw }
            let answer: Answer = switch row {
            case nil: .notInvited
            case let row? where row.inviteResponseStatus == "declined": .declined
            case let row? where row.hasAnswered || loaded.payable.isZero: .accepted
            default: .open
            }
            // The server's figure for my share (no service fee for an invitee).
            checkout.updatePrice(PriceBreakdown(subtotal: loaded.payable))
            state = .loaded(Content(booking: loaded, answer: answer))
        } catch let error as AppError {
            state = .failed(error)
        } catch {
            state = .failed(.unknown)
        }
    }

    public func confirmDecline() async {
        isDeclineConfirmPresented = false
        isDeclining = true
        defer { isDeclining = false }
        do {
            _ = try await courts.declineInvite(bookingID)
            changes?.notificationsChanged()
            toasts.show(Toast(.info, L10n.Notifications.inviteDeclined))
            router.goBack()
        } catch {
            toasts.show(error)
        }
    }

    // MARK: - CheckoutOrder

    public func placeOrder(
        _ method: PurchasePaymentMethod,
        idempotencyKey: String
    ) async throws(AppError) -> PaymentPurpose {
        _ = try await courts.acceptInvite(bookingID, method: method, idempotencyKey: idempotencyKey)
        // By card the share is settled by this checkout; by wallet or cash it already is.
        return .courtBooking(bookingID)
    }

    public func orderPaid() {
        guard let booking = state.value?.booking else { return }
        changes?.walletChanged()
        changes?.notificationsChanged()
        router.push(.bookingInviteAccepted(BookingInviteReceipt(booking: booking, paid: checkout.total)))
    }

    public func orderProcessing() {
        changes?.walletChanged()
        router.goBack()
    }
}
