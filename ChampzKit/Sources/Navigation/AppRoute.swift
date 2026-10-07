import Foundation

/// Every pushable destination in the app. IDs only, never models or views: the App
/// target maps each case to a view (`AppDestinations`), so features never import each other.
public enum AppRoute: Hashable, Sendable {
    case matchesList
    case matchDetail(MatchID)
    case matchTeams(MatchID)
    /// The join flow (registration → payment). `waitingList` when the spot is a waiting-list spot.
    case joinMatch(MatchID, waitingList: Bool)
    case confirmJoin(JoinDraft)
    case joinDone(JoinReceipt)
    case venuesList
    case venueDetail(VenueID)
    /// Description, hours, map, contact.
    case venueInfo(Venue)
    /// Booking details and friends.
    case bookCourt(CourtBookingDraft)
    /// Payment.
    case confirmCourtBooking(CourtBookingDraft)
    case courtBooked(CourtBookingReceipt)
    /// Someone invited me to share their court booking: see it, then pay my share or decline.
    case bookingInvite(BookingID)
    case bookingInviteAccepted(BookingInviteReceipt)
    case bookingDetail(BookingID)
    case tournamentsList
    case tournamentDetail(TournamentID)
    /// "Who's playing": players and teams registered.
    case tournamentParticipants(TournamentID)
    /// Booking details + payment on one screen.
    case joinTournament(Tournament)
    case tournamentJoined(TournamentReceipt)
    case teamDetail(TeamID)
    case playerProfile(PlayerID)
    case chat(MatchID)
    case walletHistory
    case topUp
    case topUpDone(TopupReceipt)
    case notifications
    case settings
    case notificationSettings
    case faq
    case about
    case legalPage(CmsPageType)
    case deleteAccount
    case history
    /// A past or upcoming court booking from "My History": its receipt.
    case historyBooking(HistoryItem)
    /// Debug builds: the design system catalog, from Settings.
    case designSystemCatalog
}

/// Modal destinations. Checkout and onboarding are full-screen; the rest are sheets.
public enum AppSheet: Hashable, Sendable, Identifiable {
    case editProfile
    case matchFilters

    public var id: Self {
        self
    }

    public var isFullScreen: Bool {
        switch self {
        case .editProfile, .matchFilters: false
        }
    }
}
