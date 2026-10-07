import SwiftUI

/// "Who's playing": the registered players, and the teams when there are any.
/// Reloads the tournament on open so the lists are current.
public struct TournamentParticipantsView: View {
    @State var viewModel: TournamentDetailViewModel
    @State private var showsTeams = false

    public init(viewModel: TournamentDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        LoadableView(viewModel.state, retry: { await viewModel.reload() }) { tournament in
            ScrollView {
                VStack(spacing: Spacing.l) {
                    if !tournament.joinTeamData.isEmpty {
                        Picker(selection: $showsTeams) {
                            Text(L10n.Court.players).tag(false)
                            Text(L10n.Tournament.teams).tag(true)
                        } label: {
                            EmptyView()
                        }
                        .pickerStyle(.segmented)
                    }
                    if showsTeams {
                        grid(tournament.joinTeamData, onTap: viewModel.openTeam)
                    } else {
                        grid(tournament.joinPayerData, onTap: viewModel.openPlayer)
                    }
                }
                .padding(Spacing.gutter)
            }
            .refreshable { await viewModel.reload() }
        }
        .background(Color.ds.backgroundMuted)
        .navigationTitle(Text(L10n.Tournaments.whoIsPlaying))
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.reload() }
    }

    @ViewBuilder
    private func grid<Item: HasAvatar & Identifiable>(_ items: [Item], onTap: @escaping (Item) -> Void) -> some View {
        if items.isEmpty {
            Text(L10n.Tournaments.noParticipants)
                .font(AppFont.detailBody)
                .foregroundStyle(.ds.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: Spacing.l), GridItem(.flexible())], spacing: Spacing.l) {
                ForEach(items) { item in
                    Button { onTap(item) } label: { PlayerCard(name: item.name, image: item.image) }
                        .buttonStyle(.plain)
                }
            }
        }
    }
}
