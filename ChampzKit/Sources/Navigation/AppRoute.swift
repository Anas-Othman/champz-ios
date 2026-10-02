import Domain
import Foundation

/// Every pushable destination in the app. IDs only, never models or views: the App
/// target maps each case to a view (`AppDestinations`), so features never import each other.
public enum AppRoute: Hashable, Sendable {
    case matchDetail(MatchID)
    case venueDetail(VenueID)
    case bookingDetail(BookingID)
    case tournamentDetail(TournamentID)
    case teamDetail(TeamID)
    case playerProfile(PlayerID)
    case chat(MatchID)
    case walletHistory
    case notifications
    case settings
}

/// Modal destinations. Checkout and onboarding are full-screen; the rest are sheets.
public enum AppSheet: Hashable, Sendable, Identifiable {
    case checkout(PaymentPurpose)
    case editProfile
    case matchFilters

    public var id: Self {
        self
    }

    public var isFullScreen: Bool {
        switch self {
        case .checkout: true
        case .editProfile, .matchFilters: false
        }
    }
}
