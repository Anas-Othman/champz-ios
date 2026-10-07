import SwiftUI

/// The Transfer Market tab: search in the bar, filter and notifications buttons,
/// then "Our Top Talents" (a horizontal row) and "Our Talents" (the list).
public struct TransferMarketView: View {
    @State var viewModel: TransferMarketViewModel
    @State private var searchText = ""

    public init(viewModel: TransferMarketViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        content
            .background(Color.ds.backgroundMuted)
            // No title on the tab's root screen; the bar keeps search, filter and the bell.
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: Text(L10n.TransferMarket.searchPlayers)
            )
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button(action: viewModel.openFilters) {
                        Image(.filter)
                            .overlay(alignment: .topTrailing) {
                                if viewModel.filter.activeCount > 0 {
                                    Text(verbatim: "\(viewModel.filter.activeCount)")
                                        .font(AppFont.captionSmall.weight(.bold))
                                        .foregroundStyle(.ds.onBrand)
                                        .frame(width: 16, height: 16)
                                        .background(Color.ds.accent, in: Circle())
                                        .offset(x: 8, y: -8)
                                }
                            }
                    }
                    .accessibilityLabel(Text(L10n.Market.filter))
                    NotificationBell(action: viewModel.openNotifications)
                }
            }
            .sheet(isPresented: $viewModel.isFilterSheetPresented) {
                MarketFilterSheet(
                    filter: viewModel.filter,
                    positions: viewModel.positions,
                    nationalities: viewModel.nationalities
                ) { newFilter in
                    Task { await viewModel.apply(newFilter) }
                }
            }
            .task { await viewModel.load() }
            // Search a moment after typing stops; clearing the field brings everyone back.
            .task(id: searchText) {
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
                await viewModel.search(searchText)
            }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.talents {
        case .idle, .loading:
            ListSkeleton(rows: 6)
        case let .failed(error):
            ErrorStateView(error: error) { await viewModel.refresh() }
        case let .loaded(players):
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Spacing.m) {
                    if !viewModel.topTalents.isEmpty {
                        sectionTitle(L10n.TransferMarket.ourTopTalents)
                        topTalents
                    }
                    HStack {
                        sectionTitle(L10n.TransferMarket.ourTalents)
                        if viewModel.isRefreshing {
                            ProgressView().padding(.leading, Spacing.s)
                        }
                    }
                    .padding(.top, viewModel.topTalents.isEmpty ? 0 : Spacing.m)
                    if players.isEmpty {
                        EmptyStateView(title: L10n.TransferMarket.noPlayersFound, icon: .players).frame(height: 220)
                    }
                    ForEach(players) { player in
                        Button { viewModel.open(player) } label: { TalentRow(player: player) }
                            .buttonStyle(.plain)
                            .task { await viewModel.loadMoreIfNeeded(after: player) }
                    }
                    if viewModel.isLoadingMore {
                        ProgressView().frame(maxWidth: .infinity).padding(Spacing.l)
                    }
                }
                .padding(Spacing.gutter)
            }
            .scrollDismissesKeyboard(.immediately)
            .refreshable { await viewModel.refresh() }
        }
    }

    private var topTalents: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: Spacing.m) {
                ForEach(viewModel.topTalents) { player in
                    Button { viewModel.open(player) } label: { TopTalentCard(player: player) }
                        .buttonStyle(.plain)
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, 38) // room for the avatar sitting on the card's top edge
        }
        .scrollTargetBehavior(.viewAligned)
        .padding(.horizontal, -Spacing.gutter)
    }

    private func sectionTitle(_ title: LocalizedStringResource) -> some View {
        Text(title).font(AppFont.sectionTitle).foregroundStyle(.ds.textPrimary)
    }
}

/// White card with the avatar overlapping its top edge: name, "Position | Age", goals and games.
struct TopTalentCard: View {
    let player: MarketPlayer

    var body: some View {
        VStack(spacing: Spacing.xs) {
            Text(verbatim: player.player.fullName)
                .font(AppFont.bodyEmphasis.weight(.bold))
                .foregroundStyle(.ds.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2, reservesSpace: true)
            Text(verbatim: player.positionAndAge)
                .font(AppFont.caption)
                .foregroundStyle(.ds.textSecondary)
                .lineLimit(1)
            GoalsLine(player: player).padding(.top, Spacing.xs)
        }
        .padding(.horizontal, Spacing.m)
        .padding(.top, 46)
        .padding(.bottom, Spacing.l)
        .frame(width: 148)
        .background(Color.ds.surface, in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
        .overlay(alignment: .top) {
            AvatarView(url: player.player.avatarUrl, name: player.player.fullName, size: 76)
                .overlay(Circle().strokeBorder(Color.ds.brandPrimary, lineWidth: 3))
                .offset(y: -38)
        }
        .accessibilityElement(children: .combine)
    }
}

/// One "Our Talents" row: avatar, name, "Position | Age", goals and games, chevron.
struct TalentRow: View {
    let player: MarketPlayer

    var body: some View {
        HStack(spacing: Spacing.m) {
            AvatarView(url: player.player.avatarUrl, name: player.player.fullName, size: 54)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(verbatim: player.player.fullName)
                    .font(AppFont.bodyEmphasis.weight(.bold))
                    .foregroundStyle(.ds.textPrimary)
                    .lineLimit(1)
                if !player.positionAndAge.isEmpty {
                    Text(verbatim: player.positionAndAge).font(AppFont.caption).foregroundStyle(.ds.textSecondary)
                }
                GoalsLine(player: player)
            }
            Spacer(minLength: 0)
            Image(.chevronRight).font(.footnote).foregroundStyle(.ds.textTertiary)
        }
        .padding(Spacing.m)
        .background(Color.ds.surface, in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Ball icon + "12 Goals / Last 30 Games".
private struct GoalsLine: View {
    let player: MarketPlayer

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(.football).font(.caption).foregroundStyle(.ds.accent)
            Text(verbatim: L10n.Market.goalsAndGames(player.goals, player.matchesPlayed))
                .font(AppFont.captionSmall.weight(.medium))
                .foregroundStyle(.ds.textSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
