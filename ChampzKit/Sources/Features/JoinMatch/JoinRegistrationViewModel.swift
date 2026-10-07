import Foundation
import Observation

/// "JOIN MATCH": booking details, optional friends / one guest, and the estimated total.
/// Nothing is sent to the server here; Continue carries a `JoinDraft` to the confirm screen.
@MainActor
@Observable
public final class JoinRegistrationViewModel {
    public let matchID: MatchID
    public let isWaitingList: Bool
    public private(set) var state: Loadable<Match> = .idle
    public private(set) var fee = Money.zero(Money.defaultCurrency)

    public var booking = BookingInfo()
    public private(set) var friends: [FriendCandidate] = []
    public var isGuestSelected = false
    public var guestEmail = ""
    public var isFriendPickerPresented = false
    public private(set) var errors: [BookingInfo.Field: String] = [:]
    public private(set) var guestEmailError: String?

    private let matches: any MatchRepository
    private let auth: any AuthRepository
    private let content: any ContentRepository
    private let router: AppRouter
    private let toasts: ToastCenter

    public init(
        matchID: MatchID,
        isWaitingList: Bool,
        matches: any MatchRepository,
        auth: any AuthRepository,
        content: any ContentRepository,
        router: AppRouter,
        toasts: ToastCenter
    ) {
        self.matchID = matchID
        self.isWaitingList = isWaitingList
        self.matches = matches
        self.auth = auth
        self.content = content
        self.router = router
        self.toasts = toasts
    }

    /// Loads the match, the service fee and the profile prefill together.
    public func load() async {
        guard case .idle = state else { return }
        state = .loading
        do {
            async let match = matches.match(matchID)
            async let settings = content.settings()
            async let user = auth.currentUser()
            let (loaded, serverSettings, account) = try await (match, settings, user)
            fee = serverSettings.gameFee
            booking = BookingInfo(user: account)
            state = .loaded(loaded)
        } catch let error as AppError {
            state = .failed(error)
        } catch {
            state = .failed(.unknown)
        }
    }

    // MARK: - Party

    public var match: Match? {
        state.value
    }

    public var remainingSlots: Int {
        match?.spotsLeft ?? 0
    }

    public var partySize: Int {
        1 + friends.count + (isGuestSelected ? 1 : 0)
    }

    /// Friends that still fit: remaining spots minus me minus the guest.
    public var maxFriends: Int {
        max(0, remainingSlots - 1 - (isGuestSelected ? 1 : 0))
    }

    public var canAddFriends: Bool {
        maxFriends > 0 || !friends.isEmpty
    }

    public var canAddGuest: Bool {
        remainingSlots - 1 - friends.count > 0 || isGuestSelected
    }

    public func setFriends(_ selected: [FriendCandidate]) {
        friends = Array(selected.prefix(maxFriends))
    }

    public func toggleFriends() {
        if friends.isEmpty {
            isFriendPickerPresented = true
        } else {
            friends = []
        }
    }

    // MARK: - Money (estimate; the server's charge is authoritative)

    public var unitPrice: Money {
        match?.effectivePrice ?? .zero(Money.defaultCurrency)
    }

    public var price: PriceBreakdown {
        PriceBreakdown(unitPrice: unitPrice, quantity: partySize, fee: fee)
    }

    public var subtotal: Money {
        price.subtotal
    }

    public var total: Money {
        price.total
    }

    // MARK: - Continue

    public func inputChanged(_ field: BookingInfo.Field) {
        errors[field] = nil
    }

    public func guestEmailChanged() {
        guestEmailError = nil
    }

    public func continueTapped() {
        guard let match, validate() else { return }
        guard partySize <= remainingSlots else {
            toasts.show(Toast(.error, text: L10n.Join.notEnoughSlots(remainingSlots)))
            return
        }
        let draft = JoinDraft(
            match: match,
            booking: booking,
            friends: friends,
            guestEmail: isGuestSelected ? guestEmail.trimmingCharacters(in: .whitespaces) : nil,
            fee: fee
        )
        router.push(.confirmJoin(draft))
    }

    /// Booking fields use the shared `BookingInfo` rules; the guest email is this screen's own.
    @discardableResult
    func validate() -> Bool {
        errors = booking.validate()
        let guest = guestEmail.trimmingCharacters(in: .whitespaces)
        guestEmailError = isGuestSelected && !Validation.isValidEmail(guest)
            ? String(localized: L10n.FriendlyMatch.pleaseEnterEmailCorrectFormat)
            : nil
        return errors.isEmpty && guestEmailError == nil
    }
}
