import SwiftUI

/// "My History": Upcoming / Previous, filter chips, then one card per tournament, game or booking.
public struct HistoryView: View {
    @State var viewModel: HistoryViewModel

    public init(viewModel: HistoryViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        VStack(spacing: 0) {
            controls
            LoadableView(
                viewModel.state,
                isEmpty: \.isEmpty,
                emptyTitle: L10n.History.empty,
                retry: { await viewModel.reload() }
            ) { items in
                ScrollView {
                    LazyVStack(spacing: Spacing.xl) {
                        ForEach(items) { item in
                            HistoryCard(item: item, isPrevious: viewModel.filter.tab == .previous) {
                                viewModel.open(item)
                            }
                        }
                    }
                    .padding(Spacing.gutter)
                }
                .refreshable { await viewModel.reload() }
            }
        }
        .background(Color.ds.backgroundMuted)
        .navigationTitle(Text(L10n.History.title))
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }

    private var controls: some View {
        VStack(spacing: Spacing.m) {
            Picker(selection: Binding(
                get: { viewModel.filter.tab },
                set: { tab in Task { await viewModel.select(tab) } }
            )) {
                Text(L10n.History.upcoming).tag(HistoryFilter.Tab.upcoming)
                Text(L10n.History.previous).tag(HistoryFilter.Tab.previous)
            } label: {
                EmptyView()
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Spacing.gutter)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.s) {
                    FilterChip(L10n.Matches.thisWeek, isSelected: viewModel.filter.thisWeek) {
                        Task { await viewModel.toggleThisWeek() }
                    }
                    Divider().frame(height: 24)
                    ForEach(HistoryFilter.Kind.allCases, id: \.self) { kind in
                        FilterChip(kind.title, isSelected: viewModel.filter.kind == kind) {
                            Task { await viewModel.toggle(kind) }
                        }
                    }
                }
                .padding(.horizontal, Spacing.gutter)
            }
        }
        .padding(.vertical, Spacing.m)
        .background(Color.ds.background)
    }
}

extension HistoryFilter.Kind {
    var title: LocalizedStringResource {
        switch self {
        case .friendly: L10n.Matches.friendly
        case .competitive: L10n.Matches.competitive
        case .oneDay: L10n.Tournaments.oneDay
        case .league: L10n.Tournaments.league
        case .knockout: L10n.Tournaments.knockout
        }
    }
}

/// The history tile, shaped like the match and tournament cards: picture with a badge,
/// title, date, venue, and a grey price box.
struct HistoryCard: View {
    let item: HistoryItem
    let isPrevious: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: Spacing.s) {
                ZStack(alignment: .topLeading) {
                    RemoteImage(url: item.image, cornerRadius: Radius.l) {
                        ZStack {
                            Color.ds.separator
                            Image(item.type == .tournament ? AppIcon.tournamentTrophy : AppIcon.football)
                                .resizable().scaledToFit().frame(width: 36, height: 36)
                                .foregroundStyle(.ds.textTertiary)
                        }
                    }
                    .frame(height: 140)
                    if let badge {
                        badge.padding(Spacing.m)
                    }
                }
                .frame(height: 140)
                Text(verbatim: item.title.uppercased())
                    .font(AppFont.headline)
                    .foregroundStyle(.ds.textPrimary)
                    .lineLimit(1)
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        infoRow(.clock, item.whenText)
                        infoRow(.location, item.venueText)
                    }
                    Spacer(minLength: Spacing.m)
                    if let price = item.priceMoney {
                        priceBox(price)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(item.route == nil)
        .accessibilityElement(children: .combine)
    }

    /// "Finished" on past items; on an upcoming game, how full it is (red when nearly full).
    private var badge: Badge? {
        if isPrevious {
            return Badge(text: Text(L10n.History.finished), color: .ds.textSecondary)
        }
        guard item.isGame, let joined = item.joinedPlayerCount, let total = item.totalPlayerCount, total > 0 else {
            return nil
        }
        // Red only for a real near-full game. (The current app also turned bookings red: `joined >= -3`.)
        return Badge(
            text: Text(verbatim: "\(joined) / \(total)"),
            icon: .players,
            color: joined >= total - 3 ? .ds.statusError : .ds.accent
        )
    }

    private func infoRow(_ icon: AppIcon, _ text: String) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(icon).font(.caption).foregroundStyle(.ds.brandPrimary)
            Text(verbatim: text).font(AppFont.body).foregroundStyle(.ds.textSecondary).lineLimit(1)
        }
    }

    private func priceBox(_ price: Money) -> some View {
        VStack(spacing: Spacing.xxs) {
            Text(verbatim: price.compact).font(AppFont.headline.weight(.bold)).foregroundStyle(.ds.brandPrimary)
            Text(item.type == .courtBooking ? L10n.History.perBooking : L10n.History.perPlayer)
                .font(AppFont.captionSmall).foregroundStyle(.ds.brandPrimary)
            if let duration = item.duration, duration > 0 {
                Text(verbatim: L10n.Courts.minutes(duration)).font(AppFont.captionSmall.weight(.medium))
                    .foregroundStyle(.ds.textPrimary)
            }
        }
        .lineLimit(1)
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, Spacing.xs)
        .background(Color.ds.separator, in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
    }
}

/// A court booking from history: its receipt, as the ticket shown after paying.
public struct HistoryBookingView: View {
    let item: HistoryItem

    public init(item: HistoryItem) {
        self.item = item
    }

    public var body: some View {
        ScrollView {
            TicketCard(
                title: item.location,
                rows: [
                    .init(L10n.Court.billIdLabel, "#" + item.uniqueId),
                    .init(L10n.Court.amountLabel, item.priceMoney?.compact ?? "-"),
                ] + (item.paymentMethod.isEmpty ? [] : [.init(L10n.History.paidWith, item.paymentMethod.capitalized)]),
                details: [
                    item.whenText,
                    [item.name, item.surfaceType].filter { !$0.isEmpty }.joined(separator: " · "),
                    item.duration.map(L10n.Courts.minutes) ?? "",
                ]
            )
            .padding(Spacing.gutter)
        }
        .background(Color.ds.backgroundMuted)
        .navigationTitle(Text(L10n.History.receipt))
        .navigationBarTitleDisplayMode(.inline)
    }
}
