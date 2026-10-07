import SwiftUI

/// "BOOK A COURT": search, surface chips, venue cards.
public struct VenuesListView: View {
    @State var viewModel: VenuesListViewModel
    @State private var searchText = ""

    public init(viewModel: VenuesListViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        VStack(spacing: 0) {
            chips
            LoadableView(
                viewModel.state,
                isEmpty: \.isEmpty,
                emptyTitle: L10n.Court.noCourtAvailable,
                retry: { await viewModel.reload() }
            ) { venues in
                ScrollView {
                    LazyVStack(spacing: Spacing.xl) {
                        ForEach(venues) { venue in
                            VenueCard(venue: venue) { viewModel.open(venue) }
                        }
                    }
                    .padding(Spacing.gutter)
                }
                .refreshable { await viewModel.reload() }
            }
        }
        .background(Color.ds.backgroundMuted)
        .navigationTitle(Text(L10n.Home.bookACourt))
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: Text(L10n.Court.findYourCourt))
        .task { await viewModel.load() }
        .task(id: searchText) {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await viewModel.search(searchText)
        }
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.s) {
                ForEach(VenuesListViewModel.Surface.allCases, id: \.self) { surface in
                    FilterChip(surface.title, isSelected: viewModel.surface == surface) {
                        Task { await viewModel.toggle(surface) }
                    }
                }
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.vertical, Spacing.m)
        }
        .background(Color.ds.background)
    }
}

extension VenuesListViewModel.Surface {
    var title: LocalizedStringResource {
        switch self {
        case .indoor: L10n.Courts.indoor
        case .grass: L10n.Courts.grass
        case .synthetic: L10n.Courts.synthetic
        }
    }
}
