import SwiftUI

/// "Find a match": filter chips on top, cards below, infinite scroll.
public struct MatchesListView: View {
    @Environment(DataChanges.self) private var changes: DataChanges?
    @State var viewModel: MatchesListViewModel

    public init(viewModel: MatchesListViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        VStack(spacing: 0) {
            filters
            LoadableView(
                viewModel.state,
                isEmpty: \.isEmpty,
                emptyTitle: L10n.Home.noGameAvailable,
                retry: { await viewModel.refresh() }
            ) { items in
                ScrollView {
                    LazyVStack(spacing: Spacing.xl) {
                        ForEach(items) { match in
                            MatchCard(match: match) { viewModel.open(match) }
                                .task { await viewModel.loadMoreIfNeeded(after: match) }
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
        .navigationTitle(Text(L10n.Matches.findAMatch))
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .onChange(of: changes?.matchesVersion) { Task { await viewModel.refresh() } }
    }

    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.s) {
                FilterChip(L10n.Matches.allDates, isSelected: viewModel.filter.dates == .any) {
                    Task { await viewModel.apply(MatchFilter(dates: .any, competition: viewModel.filter.competition)) }
                }
                FilterChip(L10n.Matches.thisWeek, isSelected: viewModel.filter.dates == .thisWeek) {
                    Task { await viewModel.apply(MatchFilter(
                        dates: .thisWeek,
                        competition: viewModel.filter.competition
                    )) }
                }
                Divider().frame(height: 24)
                FilterChip(L10n.Matches.friendly, isSelected: viewModel.filter.competition == .friendly) {
                    Task { await viewModel.apply(MatchFilter(
                        dates: viewModel.filter.dates,
                        competition: toggle(.friendly)
                    )) }
                }
                FilterChip(L10n.Matches.competitive, isSelected: viewModel.filter.competition == .competitive) {
                    Task { await viewModel.apply(MatchFilter(
                        dates: viewModel.filter.dates,
                        competition: toggle(.competitive)
                    )) }
                }
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.vertical, Spacing.m)
        }
        .background(Color.ds.background)
    }

    private func toggle(_ competition: MatchCompetition) -> MatchCompetition? {
        viewModel.filter.competition == competition ? nil : competition
    }
}

/// Selectable pill used for list filters.
struct FilterChip: View {
    let title: LocalizedStringResource
    let isSelected: Bool
    let action: () -> Void

    init(_ title: LocalizedStringResource, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.bodyEmphasis)
                .foregroundStyle(isSelected ? Color.ds.onBrand : Color.ds.textPrimary)
                .padding(.horizontal, Spacing.l)
                .frame(height: 36)
                .background(isSelected ? Color.ds.brandPrimary : Color.ds.surfaceMuted, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
