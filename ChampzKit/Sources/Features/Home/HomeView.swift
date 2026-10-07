import Observation
import SwiftUI

/// The Home tab: greeting, wallet, then the "Upcoming matches" (`MatchCard`), "BOOK A COURT"
/// (`VenueCard`) and "Upcoming tournaments" (`TournamentCard`) rows.
@MainActor
@Observable
public final class HomeViewModel {
    public private(set) var state: Loadable<HomeFeed> = .idle
    /// "BOOK A COURT" row; its own call, and simply hidden if it fails.
    public private(set) var venues: [Venue] = []

    private let matches: any MatchRepository
    private let courts: (any CourtRepository)?
    private let router: AppRouter
    private let toasts: ToastCenter

    public init(
        matches: any MatchRepository,
        courts: (any CourtRepository)? = nil,
        router: AppRouter,
        toasts: ToastCenter
    ) {
        self.matches = matches
        self.courts = courts
        self.router = router
        self.toasts = toasts
    }

    public func load() async {
        guard case .idle = state else { return }
        state = .loading
        await refresh()
    }

    public func refresh() async {
        async let venues = try? courts?.venues(search: "", surface: nil)
        do {
            state = try await .loaded(matches.home())
        } catch {
            if case .loaded = state {
                toasts.show(error)
            } else {
                state = .failed(error)
            }
        }
        self.venues = await venues ?? self.venues
    }

    public func openVenue(_ venue: Venue) {
        router.push(.venueDetail(venue.id))
    }

    public func openAllVenues() {
        router.push(.venuesList)
    }

    public func openMatch(_ match: Match) {
        router.push(.matchDetail(match.id))
    }

    public func openAllMatches() {
        router.push(.matchesList)
    }

    public func openTournament(_ tournament: Tournament) {
        router.push(.tournamentDetail(tournament.id))
    }

    public func openAllTournaments() {
        router.push(.tournamentsList)
    }

    /// The avatar opens my profile (the My Stats tab).
    public func openProfile() {
        router.select(.myStats)
    }

    /// The menu button: settings, support, legal, log out (the current app's "More").
    public func openSettings() {
        router.push(.settings)
    }

    public func openNotifications() {
        router.push(.notifications)
    }

    public func openWallet() {
        router.push(.walletHistory)
    }
}

public struct HomeView: View {
    @Environment(DataChanges.self) private var changes: DataChanges?
    @State var viewModel: HomeViewModel

    public init(viewModel: HomeViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        LoadableView(viewModel.state, retry: { await viewModel.refresh() }) { feed in
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xxl) {
                    header(feed)
                    HomeSection(
                        L10n.Matches.upcomingMatches,
                        actionTitle: L10n.Home.viewAll,
                        action: viewModel.openAllMatches
                    ) {
                        if feed.upcomingMatches.isEmpty {
                            EmptyStateView(title: L10n.Home.noGameAvailable, icon: .football).frame(height: 200)
                        } else {
                            CardRow(feed.upcomingMatches) { match in
                                MatchCard(match: match) { viewModel.openMatch(match) }
                            }
                        }
                    }
                    HomeSection(L10n.Home.bookACourt, actionTitle: L10n.Home.viewAll, action: viewModel.openAllVenues) {
                        if viewModel.venues.isEmpty {
                            EmptyStateView(title: L10n.Court.noCourtAvailable, icon: .football).frame(height: 200)
                        } else {
                            CardRow(viewModel.venues) { venue in
                                VenueCard(venue: venue) { viewModel.openVenue(venue) }
                            }
                        }
                    }
                    HomeSection(
                        L10n.Tournament.upcomingTournaments,
                        actionTitle: L10n.Home.viewAll,
                        action: viewModel.openAllTournaments
                    ) {
                        if feed.tournaments.isEmpty {
                            EmptyStateView(title: L10n.Home.noTournamentAvailable, icon: .tournamentTrophy)
                                .frame(height: 200)
                        } else {
                            CardRow(feed.tournaments) { tournament in
                                TournamentCard(tournament: tournament) { viewModel.openTournament(tournament) }
                            }
                        }
                    }
                }
                .padding(Spacing.gutter)
            }
            .refreshable { await viewModel.refresh() }
        }
        .background(Color.ds.backgroundMuted)
        // No bar on Home: the header (greeting, wallet, bell, menu) sits right under the status bar.
        .toolbar(.hidden, for: .navigationBar)
        .task { await viewModel.load() }
        .onChange(of: changes?.matchesVersion) { Task { await viewModel.refresh() } }
        .onChange(of: changes?.tournamentsVersion) { Task { await viewModel.refresh() } }
        .onChange(of: changes?.profileVersion) { Task { await viewModel.refresh() } }
        .onChange(of: changes?.walletVersion) { Task { await viewModel.refresh() } }
    }

    private func header(_ feed: HomeFeed) -> some View {
        HStack(spacing: Spacing.m) {
            Button(action: viewModel.openProfile) {
                AvatarView(url: feed.player?.avatarUrl ?? "", name: feed.player?.fullName ?? "", size: 48)
            }
            .accessibilityLabel(Text(L10n.Profile.myProfile))
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(L10n.Auth.welcomeBack).font(AppFont.caption).foregroundStyle(.ds.textSecondary)
                Text(verbatim: feed.player?.fullName ?? "").font(AppFont.headline).foregroundStyle(.ds.textPrimary)
            }
            Spacer()
            Button(action: viewModel.openWallet) {
                HStack(spacing: Spacing.xs) {
                    Image(.wallet)
                    Text(verbatim: feed.balance.compact).font(AppFont.bodyEmphasis)
                }
                .foregroundStyle(.ds.brandPrimary)
                .padding(.horizontal, Spacing.m).padding(.vertical, Spacing.s)
                .background(Color.ds.brandAccentSoft, in: Capsule())
            }
            NotificationBell(action: viewModel.openNotifications)
            Button(action: viewModel.openSettings) { Image(.more).foregroundStyle(.ds.brandPrimary) }
                .accessibilityLabel(Text(L10n.SettingsScreen.title))
        }
    }
}

/// A Home section: a bold title with View All, then its content close beneath it.
/// Sections are spaced apart by the parent; title and content stay together here.
private struct HomeSection<Content: View>: View {
    let title: LocalizedStringResource
    let actionTitle: LocalizedStringResource
    let action: () -> Void
    @ViewBuilder let content: Content

    init(
        _ title: LocalizedStringResource,
        actionTitle: LocalizedStringResource,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.actionTitle = actionTitle
        self.action = action
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            SectionHeader(title, actionTitle: actionTitle, action: action)
            content
        }
    }
}

/// A horizontal row of 300pt cards that runs edge to edge past the screen padding.
private struct CardRow<Item: Identifiable, Card: View>: View {
    let items: [Item]
    let card: (Item) -> Card

    init(_ items: [Item], @ViewBuilder card: @escaping (Item) -> Card) {
        self.items = items
        self.card = card
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: Spacing.l) {
                ForEach(items) { item in
                    card(item).frame(width: 300)
                }
            }
            .padding(.horizontal, Spacing.gutter)
        }
        .padding(.horizontal, -Spacing.gutter)
    }
}
