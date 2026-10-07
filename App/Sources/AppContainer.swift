import ChampzKit
import PassKit
import SwiftUI
import UserNotifications

/// The composition root: the only type that knows every module. Builds the live
/// dependencies once and hands view models what they need through `make…` factories.
@MainActor
final class AppContainer {
    let config: AppConfig
    let session: SessionStore
    let authState = AuthState()
    let router = AppRouter()
    let toasts = ToastCenter()
    let changes = DataChanges()

    /// Authenticated client used by every repository.
    let http: HTTPClient

    // Repositories: one line each, protocol-typed so features never see the Live types.
    private(set) lazy var auth: any AuthRepository = LiveAuthRepository(http: http, session: session)
    private(set) lazy var matches: any MatchRepository = LiveMatchRepository(http: http)
    private(set) lazy var payments: any PaymentRepository = LivePaymentRepository(http: http)
    private(set) lazy var content: any ContentRepository = LiveContentRepository(http: http)
    private(set) lazy var tournaments: any TournamentRepository = LiveTournamentRepository(http: http)
    private(set) lazy var profiles: any ProfileRepository = LiveProfileRepository(http: http)
    private(set) lazy var wallet: any WalletRepository = LiveWalletRepository(http: http)
    private(set) lazy var market: any TransferMarketRepository = LiveTransferMarketRepository(http: http)
    private(set) lazy var courts: any CourtRepository = LiveCourtRepository(http: http)
    private(set) lazy var settings: any SettingsRepository = LiveSettingsRepository(http: http)
    private(set) lazy var history: any HistoryRepository = LiveHistoryRepository(http: http)
    private(set) lazy var notifications: any NotificationRepository = LiveNotificationRepository(http: http)
    /// Firestore when this build has a Firebase config, otherwise a stand-in that says chat is unavailable.
    private(set) lazy var chat: any ChatRepository = FirebaseSetup.isConfigured
        ? FirestoreChatRepository()
        : UnavailableChatRepository()
    /// Permission, tokens, banners and taps (FirebaseMessaging).
    private(set) lazy var push = PushNotifications(
        notifications: notifications,
        router: router,
        changes: changes
    ) { [unowned self] in authState.phase == .signedIn }
    /// The unread count every bell shows.
    private(set) lazy var badge = NotificationBadge(notifications: notifications) { count in
        // Same number on the app icon (ignored when notifications are not allowed).
        try? await UNUserNotificationCenter.current().setBadgeCount(count)
    }

    func makeJoinRegistration(_ id: MatchID, waitingList: Bool) -> JoinRegistrationViewModel {
        JoinRegistrationViewModel(
            matchID: id,
            isWaitingList: waitingList,
            matches: matches,
            auth: auth,
            content: content,
            router: router,
            toasts: toasts
        )
    }

    func makeFriendPicker(max: Int, selected: [FriendCandidate]) -> FriendPickerViewModel {
        FriendPickerViewModel(maxSelectable: max, selected: selected, content: content, toasts: toasts)
    }

    func makeJoinConfirm(_ draft: JoinDraft) -> JoinConfirmViewModel {
        JoinConfirmViewModel(
            draft: draft,
            matches: matches,
            payments: payments,
            content: content,
            router: router,
            toasts: toasts,
            deviceSupportsApplePay: PKPaymentAuthorizationController.canMakePayments(),
            changes: changes
        )
    }

    func makeTournamentRegistration(_ tournament: Tournament) -> TournamentRegistrationViewModel {
        TournamentRegistrationViewModel(
            tournament: tournament,
            tournaments: tournaments,
            auth: auth,
            payments: payments,
            content: content,
            router: router,
            toasts: toasts,
            deviceSupportsApplePay: PKPaymentAuthorizationController.canMakePayments(),
            changes: changes
        )
    }

    func makeChat(_ id: MatchID) -> ChatViewModel {
        ChatViewModel(matchID: id, chat: chat, matches: matches, profiles: profiles, router: router, toasts: toasts)
    }

    func makeSettings() -> SettingsViewModel {
        SettingsViewModel(
            payments: payments,
            router: router,
            versionText: L10n.SettingsScreen.version(config.appVersion, config.buildNumber)
        ) { [unowned self] in await signOut() }
    }

    /// After the server deletes the account every token is dead: only this phone needs clearing.
    func makeDeleteAccount() -> DeleteAccountViewModel {
        DeleteAccountViewModel(settings: settings, toasts: toasts) { [unowned self] in await signOut() }
    }

    func makeNotifications() -> NotificationsViewModel {
        NotificationsViewModel(
            notifications: notifications,
            courts: courts,
            router: router,
            toasts: toasts,
            changes: changes
        )
    }

    func makeBookingInvite(_ id: BookingID) -> BookingInviteViewModel {
        BookingInviteViewModel(
            bookingID: id,
            courts: courts,
            auth: auth,
            payments: payments,
            content: content,
            router: router,
            toasts: toasts,
            deviceSupportsApplePay: PKPaymentAuthorizationController.canMakePayments(),
            changes: changes
        )
    }

    func makeVenueDetail(_ id: VenueID) -> VenueDetailViewModel {
        VenueDetailViewModel(venueID: id, courts: courts, router: router, toasts: toasts, webURL: config.webURL)
    }

    func makeCourtBookingSummary(_ draft: CourtBookingDraft) -> CourtBookingSummaryViewModel {
        CourtBookingSummaryViewModel(draft: draft, auth: auth, content: content, router: router)
    }

    func makeCourtBookingConfirm(_ draft: CourtBookingDraft) -> CourtBookingConfirmViewModel {
        CourtBookingConfirmViewModel(
            draft: draft,
            courts: courts,
            payments: payments,
            content: content,
            router: router,
            toasts: toasts,
            deviceSupportsApplePay: PKPaymentAuthorizationController.canMakePayments(),
            changes: changes
        )
    }

    func makeTransferMarket() -> TransferMarketViewModel {
        TransferMarketViewModel(market: market, profiles: profiles, router: router, toasts: toasts)
    }

    func makeWallet() -> WalletViewModel {
        WalletViewModel(wallet: wallet, payments: payments, router: router, toasts: toasts)
    }

    func makeTopUp() -> TopUpViewModel {
        TopUpViewModel(
            wallet: wallet,
            payments: payments,
            content: content,
            router: router,
            toasts: toasts,
            deviceSupportsApplePay: PKPaymentAuthorizationController.canMakePayments(),
            changes: changes
        )
    }

    func makeMyStats() -> MyStatsViewModel {
        MyStatsViewModel(profiles: profiles, payments: payments, router: router, toasts: toasts)
    }

    func makePlayerProfile(_ id: PlayerID) -> PlayerProfileViewModel {
        PlayerProfileViewModel(playerID: id, profiles: profiles, toasts: toasts)
    }

    func makeEditProfile() -> EditProfileViewModel {
        EditProfileViewModel(profiles: profiles, router: router, toasts: toasts, changes: changes)
    }

    /// View-model factories: the only place that knows how a screen is assembled.
    func makeMatchDetail(_ id: MatchID) -> MatchDetailViewModel {
        MatchDetailViewModel(
            matchID: id,
            matches: matches,
            router: router,
            toasts: toasts,
            webURL: config.webURL,
            changes: changes
        )
    }

    func makeTournamentDetail(_ id: TournamentID) -> TournamentDetailViewModel {
        TournamentDetailViewModel(
            tournamentID: id,
            tournaments: tournaments,
            router: router,
            toasts: toasts,
            webURL: config.webURL,
            changes: changes
        )
    }

    init(config: AppConfig, secureStore: any SecureStore = KeychainStore()) {
        self.config = config
        session = SessionStore(store: secureStore)

        // Full request/response dumps in debug builds only; release logs the one-line summary.
        #if DEBUG
            let logging = LoggingInterceptor(logsBodies: true)
        #else
            let logging = LoggingInterceptor()
        #endif

        // Refreshes go through a client WITHOUT the auth interceptor, so they cannot recurse.
        let anonymous = HTTPClient(
            baseURL: config.apiBaseURL,
            interceptors: [
                HeadersInterceptor(appVersion: config.appVersion, buildNumber: config.buildNumber),
                logging,
            ]
        )
        http = HTTPClient(
            baseURL: config.apiBaseURL,
            interceptors: [
                HeadersInterceptor(appVersion: config.appVersion, buildNumber: config.buildNumber),
                AuthInterceptor(session: session),
                logging,
            ]
        )

        let authState = authState
        Task {
            await session.configure(refresher: LiveTokenRefresher(http: anonymous)) {
                await MainActor.run { authState.transition(to: .signedOut) }
            }
        }
    }

    /// Restores the session from the Keychain and settles the root UI.
    /// A restored token is checked against `/auth/me`; only a definitive rejection signs out,
    /// an offline launch stays signed in (the current app behaves the same).
    func bootstrap() async {
        guard await session.restore() else {
            authState.transition(to: .signedOut)
            return
        }
        do {
            _ = try await auth.currentUser()
            authState.transition(to: .signedIn)
        } catch .unauthorized, .forbidden {
            await session.clear()
            authState.transition(to: .signedOut)
        } catch {
            Log.auth.notice("Session check failed (\(String(describing: error), privacy: .public)); staying signed in")
            authState.transition(to: .signedIn)
        }
        router.replayPendingDeepLink()
        if authState.phase == .signedIn {
            await push.start()
        }
    }

    /// Sign-in lands in the tabs; sign-up goes to profile setup first.
    func signedIn(_ session: AuthSession, via mode: AuthMode) {
        let via = String(describing: mode)
        Log.auth.info("Signed in as \(session.user.id, privacy: .public) via \(via, privacy: .public)")
        authState.transition(to: mode == .signUp ? .needsProfile : .signedIn)
        router.replayPendingDeepLink()
        Task { await push.start() }
    }

    func signOut() async {
        await push.stop()
        await session.clear()
        router.popToRoot()
        router.dismissSheet()
        authState.transition(to: .signedOut)
    }

    func open(url: URL) {
        guard let link = DeepLinkParser.parse(url) else {
            Log.navigation.notice("Unrecognised link: \(url.absoluteString, privacy: .public)")
            return
        }
        router.open(link, isSignedIn: authState.phase == .signedIn)
    }
}

extension AppContainer {
    /// For `#Preview` and the app test bundle: memory-only storage, no Keychain prompts.
    static let preview = AppContainer(config: .preview, secureStore: InMemorySecureStore())
}
