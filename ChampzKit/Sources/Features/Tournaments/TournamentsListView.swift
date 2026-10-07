import SwiftUI

/// "Compete": filter chips on top, tournament cards below, infinite scroll.
public struct TournamentsListView: View {
    @Environment(DataChanges.self) private var changes: DataChanges?
    @State var viewModel: TournamentsListViewModel

    public init(viewModel: TournamentsListViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        VStack(spacing: 0) {
            filters
            LoadableView(
                viewModel.state,
                isEmpty: \.isEmpty,
                emptyTitle: L10n.Home.noTournamentAvailable,
                retry: { await viewModel.refresh() }
            ) { items in
                ScrollView {
                    LazyVStack(spacing: Spacing.xl) {
                        ForEach(items) { tournament in
                            TournamentCard(tournament: tournament) { viewModel.open(tournament) }
                                .task { await viewModel.loadMoreIfNeeded(after: tournament) }
                        }
                        if viewModel.isLoadingMore {
                            ProgressView().padding(Spacing.l)
                        }
                    }
                    .padding(Spacing.gutter)
                }
                .refreshable { await viewModel.refresh() }
            }
        }
        .background(Color.ds.backgroundMuted)
        .navigationTitle(Text(L10n.Tournaments.tournaments))
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .onChange(of: changes?.tournamentsVersion) { Task { await viewModel.refresh() } }
    }

    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.s) {
                FilterChip(L10n.Matches.thisWeek, isSelected: viewModel.filter.thisWeek) {
                    Task { await viewModel.toggleThisWeek() }
                }
                Divider().frame(height: 24)
                ForEach(TournamentFilter.Kind.allCases, id: \.self) { kind in
                    FilterChip(kind.title, isSelected: viewModel.filter.kind == kind) {
                        Task { await viewModel.toggle(kind) }
                    }
                }
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.vertical, Spacing.m)
        }
        .background(Color.ds.background)
    }
}

extension TournamentFilter.Kind {
    var title: LocalizedStringResource {
        switch self {
        case .oneDay: L10n.Tournaments.oneDay
        case .league: L10n.Tournaments.league
        case .knockout: L10n.Tournaments.knockout
        case .leagueAndKnockout: L10n.Tournaments.leagueAndKnockout
        case .groupAndKnockout: L10n.Tournaments.groupAndKnockout
        }
    }
}
