import ChampzKit
import SwiftUI

/// Route → view. The one place that knows which feature renders which destination.
/// Screens not built yet show a placeholder.
enum AppDestinations {
    @MainActor
    @ViewBuilder
    static func view(for route: AppRoute, container: AppContainer) -> some View {
        switch route {
        case .matchesList, .matchDetail, .matchTeams, .joinMatch, .confirmJoin, .joinDone, .chat:
            matchesView(for: route, container: container)
        case .tournamentsList, .tournamentDetail, .tournamentParticipants, .joinTournament, .tournamentJoined:
            tournamentsView(for: route, container: container)
        case .settings, .notificationSettings, .faq, .about, .legalPage, .deleteAccount, .designSystemCatalog,
             .history, .historyBooking:
            settingsView(for: route, container: container)
        case .notifications:
            NotificationsView(viewModel: container.makeNotifications())
        case let .bookingInvite(id):
            BookingInviteView(viewModel: container.makeBookingInvite(id))
        case let .bookingInviteAccepted(receipt):
            PurchaseDoneView(
                title: String(localized: L10n.Court.successPaymentTitle),
                rows: [
                    .init(L10n.Court.billIdLabel, "#" + receipt.booking.uniqueId),
                    .init(L10n.Court.amountLabel, receipt.paid.compact),
                ],
                details: [receipt.booking.whenText, receipt.booking.venueName + " · " + receipt.booking.courtName],
                toast: L10n.Join.youreIn,
                backTitle: L10n.Payment.backToHome
            ) {
                container.router.popToRoot()
            }
        case .walletHistory, .topUp, .topUpDone:
            walletView(for: route, container: container)
        case let .playerProfile(id):
            PlayerProfileView(viewModel: container.makePlayerProfile(id))
        case .venuesList, .venueDetail, .venueInfo, .bookCourt, .confirmCourtBooking, .courtBooked:
            courtsView(for: route, container: container)
        case .bookingDetail, .teamDetail:
            PlaceholderScreen(title: L10n.Common.pleaseWait, icon: .football)
        }
    }

    @MainActor
    @ViewBuilder
    private static func matchesView(for route: AppRoute, container: AppContainer) -> some View {
        switch route {
        case .matchesList:
            MatchesListView(viewModel: MatchesListViewModel(
                matches: container.matches,
                router: container.router,
                toasts: container.toasts
            ))
        case let .matchDetail(id):
            MatchDetailView(viewModel: container.makeMatchDetail(id))
        case let .matchTeams(id):
            MatchTeamsView(viewModel: container.makeMatchDetail(id))
        case let .joinMatch(id, waitingList):
            JoinRegistrationView(viewModel: container.makeJoinRegistration(
                id,
                waitingList: waitingList
            )) { max, selected in
                container.makeFriendPicker(max: max, selected: selected)
            }
        case let .confirmJoin(draft):
            JoinConfirmView(viewModel: container.makeJoinConfirm(draft))
        case let .chat(id):
            ChatView(viewModel: container.makeChat(id))
        case let .joinDone(receipt):
            PurchaseDoneView(
                title: receipt.match.title,
                rows: PurchaseDoneView.Row.join(receipt.joinRequest),
                details: [receipt.match.kickoffDetailText, receipt.match.venueName],
                toast: L10n.Join.youreIn,
                backTitle: L10n.FriendlyMatch.backToGame,
                shareMessage: container.makeMatchDetail(receipt.match.id).shareMessage(for: receipt.match)
            ) {
                container.router.popTo(.matchDetail(receipt.match.id))
            }
        default:
            EmptyView()
        }
    }

    @MainActor
    @ViewBuilder
    private static func settingsView(for route: AppRoute, container: AppContainer) -> some View {
        switch route {
        case .settings:
            SettingsView(viewModel: container.makeSettings())
        case .notificationSettings:
            NotificationSettingsView(viewModel: NotificationSettingsViewModel(
                settings: container.settings,
                toasts: container.toasts
            ))
        case .faq:
            FaqView(viewModel: FaqViewModel(settings: container.settings))
        case .about:
            AboutView(viewModel: AboutViewModel(content: container.content))
        case let .legalPage(type):
            CmsPageView(viewModel: CmsPageViewModel(type: type, settings: container.settings))
        case .deleteAccount:
            DeleteAccountView(viewModel: container.makeDeleteAccount())
        case .history:
            HistoryView(viewModel: HistoryViewModel(history: container.history, router: container.router))
        case let .historyBooking(item):
            HistoryBookingView(item: item)
        case .designSystemCatalog:
            #if DEBUG
                DesignSystemCatalogView()
            #else
                EmptyView()
            #endif
        default:
            EmptyView()
        }
    }

    @MainActor
    @ViewBuilder
    private static func courtsView(for route: AppRoute, container: AppContainer) -> some View {
        switch route {
        case .venuesList:
            VenuesListView(viewModel: VenuesListViewModel(
                courts: container.courts,
                router: container.router,
                toasts: container.toasts
            ))
        case let .venueDetail(id):
            VenueDetailView(viewModel: container.makeVenueDetail(id))
        case let .venueInfo(venue):
            VenueInfoView(venue: venue)
        case let .bookCourt(draft):
            CourtBookingSummaryView(viewModel: container.makeCourtBookingSummary(draft)) { max, selected in
                container.makeFriendPicker(max: max, selected: selected)
            }
        case let .confirmCourtBooking(draft):
            CourtBookingConfirmView(viewModel: container.makeCourtBookingConfirm(draft))
        case let .courtBooked(receipt):
            PurchaseDoneView(
                title: String(localized: L10n.Court.successPaymentTitle),
                rows: [
                    .init(L10n.Court.billIdLabel, "#" + receipt.booking.uniqueId),
                    .init(L10n.Court.amountLabel, receipt.booking.hostCharge.compact),
                ],
                details: [
                    receipt.draft.whenText,
                    receipt.draft.venue.name + " · " + receipt.courtName,
                ],
                toast: L10n.Courts.bookingConfirmedToast,
                backTitle: L10n.Payment.backToHome
            ) {
                container.router.popToRoot()
            }
        default:
            EmptyView()
        }
    }

    @MainActor
    @ViewBuilder
    private static func walletView(for route: AppRoute, container: AppContainer) -> some View {
        switch route {
        case .walletHistory:
            WalletView(viewModel: container.makeWallet())
        case .topUp:
            TopUpView(viewModel: container.makeTopUp())
        case let .topUpDone(receipt):
            PurchaseDoneView(
                title: String(localized: L10n.Payment.topUpSuccess),
                rows: [.init(L10n.Court.amountLabel, receipt.amount.compact)]
                    + (receipt.bonus.map { [.init(L10n.Wallet.bonus, "+ " + $0.compact)] } ?? []),
                details: [String(localized: L10n.Payment.belowIsYourTopUpSummary)],
                backTitle: L10n.Wallet.backToWallet
            ) {
                container.router.popTo(.walletHistory)
            }
        default:
            EmptyView()
        }
    }

    @MainActor
    @ViewBuilder
    private static func tournamentsView(for route: AppRoute, container: AppContainer) -> some View {
        switch route {
        case .tournamentsList:
            TournamentsListView(viewModel: TournamentsListViewModel(
                tournaments: container.tournaments,
                router: container.router,
                toasts: container.toasts
            ))
        case let .tournamentDetail(id):
            TournamentDetailView(viewModel: container.makeTournamentDetail(id))
        case let .tournamentParticipants(id):
            TournamentParticipantsView(viewModel: container.makeTournamentDetail(id))
        case let .joinTournament(tournament):
            TournamentRegistrationView(viewModel: container.makeTournamentRegistration(tournament))
        case let .tournamentJoined(receipt):
            PurchaseDoneView(
                title: receipt.tournament.name,
                rows: PurchaseDoneView.Row.join(receipt.joinRequest),
                details: [receipt.tournament.cardDateText, receipt.tournament.venueText],
                toast: L10n.Join.youreIn,
                backTitle: L10n.Team.tournamentDetails,
                shareMessage: container.makeTournamentDetail(receipt.tournament.id)
                    .shareMessage(for: receipt.tournament)
            ) {
                container.router.popTo(.tournamentDetail(receipt.tournament.id))
            }
        default:
            EmptyView()
        }
    }

    @MainActor
    @ViewBuilder
    static func view(for sheet: AppSheet, container: AppContainer) -> some View {
        switch sheet {
        case .editProfile:
            EditProfileView(viewModel: container.makeEditProfile())
        case .matchFilters:
            PlaceholderScreen(title: L10n.Common.selectOptions, icon: .filter)
        }
    }
}

/// Stand-in for screens not yet ported. Lets navigation and deep links be exercised end to end.
struct PlaceholderScreen: View {
    let title: LocalizedStringResource
    let icon: AppIcon

    var body: some View {
        EmptyStateView(title: title, icon: icon)
            .navigationTitle(Text(title))
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.ds.background)
    }
}
