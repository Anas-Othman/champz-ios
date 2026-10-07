import Foundation
import Observation

/// "BOOKING SUMMARY" (booking_summary_screen.dart): the slot, booking details, friends to split
/// with, and the estimate. Nothing is sent here; Continue carries the draft to the checkout.
@MainActor
@Observable
public final class CourtBookingSummaryViewModel {
    /// The friend picker needs a cap; court bookings have none in the current app.
    static let maxFriends = 30

    public private(set) var state: Loadable<CourtBookingDraft> = .idle
    public var booking = BookingInfo()
    public private(set) var friends: [FriendCandidate] = []
    public var isFriendPickerPresented = false
    public private(set) var errors: [BookingInfo.Field: String] = [:]

    private let initial: CourtBookingDraft
    private let auth: any AuthRepository
    private let content: any ContentRepository
    private let router: AppRouter

    public init(
        draft: CourtBookingDraft,
        auth: any AuthRepository,
        content: any ContentRepository,
        router: AppRouter
    ) {
        initial = draft
        self.auth = auth
        self.content = content
        self.router = router
    }

    /// The server's court fee and who I am (host id + prefill) together.
    public func load() async {
        guard case .idle = state else { return }
        state = .loading
        do {
            async let settings = content.settings()
            async let user = auth.currentUser()
            let (serverSettings, account) = try await (settings, user)
            var draft = initial
            draft.fee = serverSettings.courtFee
            draft.hostID = account.id
            booking = BookingInfo(user: account)
            state = .loaded(draft)
        } catch let error as AppError {
            state = .failed(error)
        } catch {
            state = .failed(.unknown)
        }
    }

    /// The draft with what is on screen now: estimates follow the friends as they change.
    public var draft: CourtBookingDraft? {
        guard var draft = state.value else { return nil }
        draft.booking = booking
        draft.friends = friends
        return draft
    }

    public func setFriends(_ picked: [FriendCandidate]) {
        friends = Array(picked.prefix(Self.maxFriends))
    }

    public func remove(_ friend: FriendCandidate) {
        friends.removeAll { $0.id == friend.id }
    }

    public func inputChanged(_ field: BookingInfo.Field) {
        errors[field] = nil
    }

    public func continueTapped() {
        guard let draft else { return }
        errors = booking.validate()
        guard errors.isEmpty else { return }
        router.push(.confirmCourtBooking(draft))
    }
}

/// "CHECKOUT": how the host pays their part. Paying is the shared `Checkout`; this type
/// books the court once per attempt and says where to go when it is paid.
@MainActor
@Observable
public final class CourtBookingConfirmViewModel: CheckoutOrder {
    public let draft: CourtBookingDraft
    public let checkout: Checkout
    private var booked: CourtBooking?

    private let courts: any CourtRepository
    private let router: AppRouter
    private let changes: DataChanges?

    public init(
        draft: CourtBookingDraft,
        courts: any CourtRepository,
        payments: any PaymentRepository,
        content: any ContentRepository,
        router: AppRouter,
        toasts: ToastCenter,
        deviceSupportsApplePay: Bool = false,
        changes: DataChanges? = nil
    ) {
        self.draft = draft
        self.courts = courts
        self.router = router
        self.changes = changes
        checkout = Checkout(
            price: draft.price,
            allowsCash: true, // shown only when the server's cash switch is on
            deviceSupportsApplePay: deviceSupportsApplePay,
            payments: payments,
            content: content,
            toasts: toasts
        )
        checkout.order = self
    }

    /// One booking per attempt, with an `Idempotency-Key`; a retry reuses it.
    /// (The current app created a new booking on every retry and every Apple Pay tap.)
    public func placeOrder(
        _ method: PurchasePaymentMethod,
        idempotencyKey: String
    ) async throws(AppError) -> PaymentPurpose {
        guard let host = draft.hostID else { throw .unauthorized }
        let booking = try await courts.book(draft, method: method, me: host, idempotencyKey: idempotencyKey)
        booked = booking
        return .courtBooking(booking.id)
    }

    public func orderPaid() {
        guard let booked else { return }
        changes?.walletChanged()
        router.push(.courtBooked(CourtBookingReceipt(draft: draft, booking: booked)))
    }

    /// Apple Pay went through but is not confirmed yet: back to the venue; the player is notified.
    public func orderProcessing() {
        changes?.walletChanged()
        router.popTo(.venueDetail(draft.venue.id))
    }
}
