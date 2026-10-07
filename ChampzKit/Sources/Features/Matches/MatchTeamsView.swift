import SwiftUI

/// "Who's playing". Opens from the players banner or the spots counter.
/// The layout follows `Match.rosterLayout`:
/// - standard game → Team Sheet with Team A / Team B,
/// - multi-team game before the deal → one grid of everyone,
/// - multi-team game after `automatic_teams_created` → a grid per team.
/// It reloads the match on open so a deal that happened meanwhile is picked up.
public struct MatchTeamsView: View {
    @State var viewModel: MatchDetailViewModel
    @State private var selectedTeam = 1

    public init(viewModel: MatchDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        LoadableView(viewModel.state, retry: { await viewModel.reload() }) { match in
            ScrollView {
                content(match).padding(Spacing.gutter)
            }
            .refreshable { await viewModel.reload() }
            .navigationTitle(Text(match.rosterLayout == .teamSheet ? L10n.Team.teamSheet : L10n.Team.teamRoster))
        }
        .background(Color.ds.backgroundMuted)
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.reload() }
    }

    @ViewBuilder
    private func content(_ match: Match) -> some View {
        switch match.rosterLayout {
        case .allPlayers:
            PlayerGrid(players: match.allPlayers, onTap: viewModel.openPlayer)
        case .groupedByTeam:
            VStack(alignment: .leading, spacing: Spacing.xl) {
                ForEach(match.teams.sorted { $0.number < $1.number }) { team in
                    teamSection(team)
                }
            }
        case .teamSheet:
            VStack(spacing: Spacing.l) {
                Picker(selection: $selectedTeam) {
                    Text(L10n.Match.teamA).tag(1)
                    Text(L10n.Match.teamB).tag(2)
                } label: {
                    EmptyView()
                }
                .pickerStyle(.segmented)
                let team = match.teams.first { $0.number == selectedTeam }
                PlayerGrid(players: team?.players ?? [], onTap: viewModel.openPlayer)
            }
        }
    }

    private func teamSection(_ team: MatchTeam) -> some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text(verbatim: team.name.isEmpty ? L10n.Matches.teamNumber(team.number) : team.name)
                .font(AppFont.sectionTitle)
                .foregroundStyle(.ds.textPrimary)
            PlayerGrid(players: team.players, onTap: viewModel.openPlayer)
        }
    }
}

/// Two-column grid of player cards; an empty team says so.
struct PlayerGrid: View {
    let players: [MatchPlayer]
    let onTap: (MatchPlayer) -> Void

    private let columns = [GridItem(.flexible(), spacing: Spacing.l), GridItem(.flexible(), spacing: Spacing.l)]

    var body: some View {
        if players.isEmpty {
            Text(L10n.Team.noPlayerAddedInThisTeam)
                .font(AppFont.detailBody)
                .foregroundStyle(.ds.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            LazyVGrid(columns: columns, spacing: Spacing.l) {
                ForEach(players.sorted { $0.ordering < $1.ordering }) { player in
                    Button { onTap(player) } label: { PlayerCard(player: player) }
                        .buttonStyle(.plain)
                }
            }
        }
    }
}

/// White card: ringed avatar with a verified badge, name in capitals, a subtitle (PlayerCard in Flutter).
struct PlayerCard: View {
    let name: String
    let image: String
    var subtitle = ""

    init(name: String, image: String, subtitle: String = "") {
        self.name = name
        self.image = image
        self.subtitle = subtitle
    }

    /// A match player: the subtitle is the position, or "Guest".
    init(player: MatchPlayer) {
        self.init(
            name: player.name,
            image: player.image,
            subtitle: player.isGuest ? String(localized: L10n.Matches.guest) : player.position
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            AvatarView(url: image, name: name, size: 45)
                .padding(3)
                .overlay(Circle().strokeBorder(Color.ds.brandPrimary, lineWidth: 3))
                .overlay(alignment: .bottomTrailing) {
                    Image(.verified).resizable().frame(width: 20, height: 20)
                }
            Text(verbatim: name.uppercased())
                .font(AppFont.infoValue.weight(.bold))
                .foregroundStyle(.ds.textPrimary)
                .lineLimit(1)
                .padding(.top, Spacing.m)
            Text(verbatim: subtitle)
                .font(AppFont.bodyEmphasis)
                .foregroundStyle(.ds.textSecondary)
                .lineLimit(1)
                .padding(.top, Spacing.xs)
        }
        .frame(maxWidth: .infinity, minHeight: 145)
        .padding(.horizontal, Spacing.s)
        .background(Color.ds.surface, in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
    }
}
