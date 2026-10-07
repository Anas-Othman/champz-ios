import SwiftUI

/// The match page (open_to_play_match_screen.dart): scrolling details with a sticky
/// join/leave bar and, once joined, a floating chat button.
public struct MatchDetailView: View {
    @Environment(DataChanges.self) private var changes: DataChanges?
    @State var viewModel: MatchDetailViewModel

    public init(viewModel: MatchDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        Group {
            if viewModel.state.error == .notFound {
                EmptyStateView(
                    title: L10n.FriendlyMatch.matchNotFound,
                    message: L10n.FriendlyMatch.matchNoLongerAvailable,
                    icon: .warning
                )
                .toolbar(.visible, for: .navigationBar)
            } else {
                LoadableView(
                    viewModel.state,
                    retry: { await viewModel.reload() },
                    placeholder: { MatchDetailSkeleton() }
                ) { match in
                    screen(match)
                }
                .toolbar(.hidden, for: .navigationBar)
            }
        }
        .background(Color.ds.backgroundMuted)
        .sheet(isPresented: $viewModel.isLeaveSheetPresented) {
            LeaveMatchSheet(
                reasons: viewModel.leaveReasons,
                playerCount: viewModel.match?.allPlayers.count ?? 0
            ) { reason in
                Task { await viewModel.leave(reason: reason) }
            }
        }
        .task { await viewModel.load() }
        .onChange(of: changes?.matchesVersion) { viewModel.refreshIfLoaded() }
    }

    private func screen(_ match: Match) -> some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                MatchDetailContent(match: match, viewModel: viewModel)
                    .padding(.bottom, 120)
            }
            .ignoresSafeArea(edges: .top)
            .refreshable { await viewModel.reload() }

            if !match.isFinished {
                MatchActionBar(match: match, isWorking: viewModel.isWorking, onSpots: viewModel.openTeamSheet) {
                    Task { await viewModel.primaryTapped() }
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if match.joinStatus, !match.isFinished {
                ChatButton(action: viewModel.openChat)
                    .padding(.trailing, Spacing.xl)
                    .padding(.bottom, 130)
            }
        }
    }
}

/// Everything above the action bar. A separate view so it can be previewed and rendered on its own.
struct MatchDetailContent: View {
    let match: Match
    let viewModel: MatchDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            MatchHero(match: match, shareMessage: viewModel.shareMessage, onBack: viewModel.goBack)
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: match.title)
                    .font(AppFont.screenTitle)
                    .foregroundStyle(.ds.textPrimary)
                DetailLine(icon: .brandClock, text: match.kickoffDetailText).padding(.top, Spacing.s)
                DetailLine(icon: .brandMapPin, text: match.venueName).padding(.top, Spacing.s)
                MatchInfoCard(match: match).padding(.top, 20)
                description.padding(.top, 30)
                if !match.allPlayers.isEmpty {
                    JoinedBanner(
                        items: match.allPlayers,
                        label: JoinedLabel.players,
                        onTap: viewModel.openTeamSheet,
                        onItemTap: viewModel.openPlayer
                    )
                    .padding(.top, 30)
                }
                location.padding(.top, 30)
                if let organizer = match.createdBy {
                    Text(L10n.FriendlyMatch.organizerDetails)
                        .font(AppFont.sectionTitle)
                        .foregroundStyle(.ds.textPrimary)
                        .padding(.top, 30)
                    OrganizerCard(organizer: organizer, fallbackPhone: match.contactNumber).padding(.top, 10)
                }
            }
            .padding(Spacing.gutter)
        }
    }

    private var description: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(L10n.Home.description).font(AppFont.sectionTitle).foregroundStyle(.ds.textPrimary)
            Text(verbatim: match.description.isEmpty ? String(localized: L10n.Matches.noDescription) : match.description
                .strippingHTML)
                .font(AppFont.detailBody)
                .foregroundStyle(.ds.textSecondary)
        }
    }

    private var location: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Spacing.m) {
                Image(.brandMapPin).resizable().scaledToFit().frame(width: 20, height: 20).foregroundStyle(.ds.accent)
                Text(L10n.Court.location).font(AppFont.sectionTitle).foregroundStyle(.ds.textPrimary)
            }
            Text(verbatim: match.location)
                .font(AppFont.detailBody)
                .foregroundStyle(.ds.textSecondary)
                .padding(.top, Spacing.s)
            if let coordinate = match.coordinate {
                MapCard(latitude: coordinate.latitude, longitude: coordinate.longitude, title: match.venueName)
                    .padding(.top, 30)
            }
        }
    }
}

#Preview("Match detail content") {
    ScrollView {
        MatchDetailContent(
            match: .preview,
            viewModel: MatchDetailViewModel(
                matchID: Match.preview.id,
                matches: PreviewMatchRepository(),
                router: AppRouter(),
                toasts: ToastCenter(),
                webURL: URL(fileURLWithPath: "/")
            )
        )
    }
    .background(Color.ds.backgroundMuted)
}

/// Serves `Match.preview` for SwiftUI previews.
struct PreviewMatchRepository: MatchRepository {
    func matches(_: MatchFilter, page _: Page) async throws(AppError) -> PageResult<Match> {
        PageResult(
            items: [.preview],
            next: nil,
            total: 1
        )
    }

    func match(_: MatchID) async throws(AppError) -> Match {
        .preview
    }

    func leaveReasons() async throws(AppError) -> [LeaveReason] {
        []
    }

    func leave(_: MatchID, reason _: String) async throws(AppError) -> LeaveResult {
        throw .unknown
    }

    func joinWaitingList(_: MatchID) async throws(AppError) {}
    func leaveWaitingList(_: MatchID) async throws(AppError) {}
    func home() async throws(AppError) -> HomeFeed {
        throw .unknown
    }

    func join(
        _: MatchID,
        _: JoinDraft,
        method _: PurchasePaymentMethod,
        idempotencyKey _: String
    ) async throws(AppError) -> JoinRequest {
        throw .unknown
    }
}
