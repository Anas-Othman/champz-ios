import SwiftUI

/// The tournament page (tournaments_details_page_screen.dart): scrolling details with a sticky
/// join/leave bar. Built from the same pieces as the match page where they match.
public struct TournamentDetailView: View {
    @Environment(DataChanges.self) private var changes: DataChanges?
    @State var viewModel: TournamentDetailViewModel

    public init(viewModel: TournamentDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        Group {
            if viewModel.state.error == .notFound {
                EmptyStateView(
                    title: L10n.Tournaments.notFound,
                    message: L10n.Tournaments.notFoundMessage,
                    icon: .warning
                )
                .toolbar(.visible, for: .navigationBar)
            } else {
                LoadableView(
                    viewModel.state,
                    retry: { await viewModel.reload() },
                    placeholder: { MatchDetailSkeleton() }
                ) { tournament in
                    screen(tournament)
                }
                .toolbar(.hidden, for: .navigationBar)
            }
        }
        .background(Color.ds.backgroundMuted)
        .sheet(isPresented: $viewModel.isLeaveSheetPresented) {
            LeaveMatchSheet(
                title: L10n.Tournament.leaveTournamentAction,
                reasons: [],
                playerCount: viewModel.tournament?.joinPayerData.count ?? 0
            ) { reason in
                Task { await viewModel.leave(reason: reason) }
            }
        }
        .task { await viewModel.load() }
        .onChange(of: changes?.tournamentsVersion) { viewModel.refreshIfLoaded() }
    }

    private func screen(_ tournament: Tournament) -> some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                TournamentDetailContent(tournament: tournament, viewModel: viewModel)
                    .padding(.bottom, 120)
            }
            .ignoresSafeArea(edges: .top)
            .refreshable { await viewModel.reload() }

            if tournament.primaryAction != .none {
                TournamentActionBar(tournament: tournament, isWorking: viewModel.isWorking) {
                    viewModel.primaryTapped()
                }
            }
        }
    }
}

/// Everything above the action bar. A separate view so it can be previewed and rendered on its own.
struct TournamentDetailContent: View {
    let tournament: Tournament
    let viewModel: TournamentDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TournamentHero(tournament: tournament, shareMessage: viewModel.shareMessage, onBack: viewModel.goBack)
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: tournament.name)
                    .font(AppFont.screenTitle)
                    .foregroundStyle(.ds.textPrimary)
                DetailLine(icon: .brandMapPin, text: tournament.venueText).padding(.top, Spacing.s)
                if tournament.isAgeBlocked {
                    AgeNotice(maxAge: tournament.maxAge).padding(.top, Spacing.l)
                }
                TournamentInfoCard(tournament: tournament).padding(.top, Spacing.l)
                pitchAndPrice.padding(.top, Spacing.l)
                textSection(L10n.Home.description, tournament.description).padding(.top, Spacing.l)
                textSection(L10n.Tournament.rules, tournament.rules).padding(.top, Spacing.xl)
                participants.padding(.top, Spacing.xl)
                location.padding(.top, Spacing.xl)
            }
            .padding(Spacing.gutter)
        }
    }

    /// White card: Pitch · Price per player.
    private var pitchAndPrice: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(L10n.Court.pitch).font(AppFont.infoLabel)
                Text(verbatim: tournament.pitch.isEmpty ? "N/A" : tournament.pitch.uppercased()).font(AppFont.infoValue)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(L10n.Court.price).font(AppFont.infoLabel)
                Text(verbatim: tournament.price.compact).font(AppFont.infoValue).foregroundStyle(.ds.brandPrimary)
                Text(L10n.Tournament.perPlayerLabel).font(AppFont.captionSmall).foregroundStyle(.ds.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(.ds.textPrimary)
        .padding(.horizontal, 20)
        .padding(.vertical, Spacing.l)
        .background(Color.ds.surface, in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
    }

    @ViewBuilder
    private func textSection(_ title: LocalizedStringResource, _ text: String) -> some View {
        if !text.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.s) {
                Text(title).font(AppFont.sectionTitle).foregroundStyle(.ds.textPrimary)
                Text(verbatim: text.strippingHTML)
                    .font(AppFont.detailBody)
                    .foregroundStyle(.ds.textSecondary)
            }
        }
    }

    /// Players banner, and the teams banner when teams have registered.
    @ViewBuilder
    private var participants: some View {
        if !tournament.joinPayerData.isEmpty || !tournament.joinTeamData.isEmpty {
            VStack(spacing: Spacing.s) {
                if !tournament.joinPayerData.isEmpty {
                    JoinedBanner(
                        items: tournament.joinPayerData,
                        label: JoinedLabel.players,
                        onTap: viewModel.openParticipants
                    )
                }
                if !tournament.joinTeamData.isEmpty {
                    JoinedBanner(
                        items: tournament.joinTeamData,
                        label: JoinedLabel.teams,
                        onTap: viewModel.openParticipants
                    )
                }
            }
        }
    }

    /// The real venue coordinates (the current app pinned a hard-coded point for every tournament).
    @ViewBuilder
    private var location: some View {
        if let ground = tournament.ground {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: Spacing.m) {
                    Image(.brandMapPin).resizable().scaledToFit().frame(width: 20, height: 20)
                        .foregroundStyle(.ds.accent)
                    Text(L10n.Court.location).font(AppFont.sectionTitle).foregroundStyle(.ds.textPrimary)
                }
                Text(verbatim: ground.location.isEmpty ? ground.name : ground.location)
                    .font(AppFont.detailBody)
                    .foregroundStyle(.ds.textSecondary)
                    .padding(.top, Spacing.s)
                if let coordinate = ground.coordinate {
                    MapCard(latitude: coordinate.latitude, longitude: coordinate.longitude, title: ground.name)
                        .padding(.top, Spacing.l)
                }
            }
        }
    }
}

#Preview("Tournament detail content") {
    ScrollView {
        TournamentDetailContent(
            tournament: .preview,
            viewModel: TournamentDetailViewModel(
                tournamentID: Tournament.preview.id,
                tournaments: PreviewTournamentRepository(),
                router: AppRouter(),
                toasts: ToastCenter(),
                webURL: URL(fileURLWithPath: "/")
            )
        )
    }
    .background(Color.ds.backgroundMuted)
}

/// Serves `Tournament.preview` for SwiftUI previews.
struct PreviewTournamentRepository: TournamentRepository {
    func tournaments(_: TournamentFilter, cursor _: String?) async throws(AppError) -> CursorPage<Tournament> {
        throw .unknown
    }

    func tournament(_: TournamentID) async throws(AppError) -> Tournament {
        .preview
    }

    func leave(_: TournamentID, reason _: String) async throws(AppError) -> TournamentLeaveResult {
        throw .unknown
    }

    func join(
        _: TournamentID,
        _: BookingInfo,
        method _: PurchasePaymentMethod,
        idempotencyKey _: String
    ) async throws(AppError) -> JoinRequest {
        throw .unknown
    }
}
