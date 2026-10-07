import SwiftUI

/// Any other player's profile (transfer_player_profile_screen.dart). Opens from rosters,
/// organizers, tournament players… Same stats widget as My Stats.
public struct PlayerProfileView: View {
    @State var viewModel: PlayerProfileViewModel

    public init(viewModel: PlayerProfileViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        LoadableView(viewModel.state, retry: { await viewModel.reload() }) { stats in
            ScrollView {
                PlayerStatsView(stats: stats, perspective: .other).padding(Spacing.gutter)
            }
            .refreshable { await viewModel.reload() }
        }
        .background(Color.ds.backgroundMuted)
        .navigationTitle(Text(L10n.PlayerProfile.profileDetails))
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }
}

/// The My Stats tab (my_stats_screen.dart): my stats with a wallet pill, Edit Profile in the bar.
public struct MyStatsView: View {
    @Environment(DataChanges.self) private var changes: DataChanges?
    @State var viewModel: MyStatsViewModel

    public init(viewModel: MyStatsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        LoadableView(viewModel.state, retry: { await viewModel.reload() }) { content in
            ScrollView {
                PlayerStatsView(stats: content.stats, perspective: .own) {
                    WalletPill(balance: content.balance, action: viewModel.openWallet)
                }
                .padding(Spacing.gutter)
            }
            .refreshable { await viewModel.reload() }
        }
        .background(Color.ds.backgroundMuted)
        // No title on the tab's root screen (the tab bar already says where you are); Edit Profile stays.
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: viewModel.editProfile) { Text(L10n.Profile.editProfile) }
            }
        }
        .task { await viewModel.load() }
        // Edit Profile saved, or a join/leave changed my record: reload so nothing is stale.
        .onChange(of: changes?.profileVersion) { Task { await viewModel.reload() } }
        .onChange(of: changes?.matchesVersion) { Task { await viewModel.reload() } }
        .onChange(of: changes?.tournamentsVersion) { Task { await viewModel.reload() } }
        .onChange(of: changes?.walletVersion) { Task { await viewModel.reload() } }
    }
}

/// "120 QR" in a soft purple capsule; opens the wallet.
struct WalletPill: View {
    let balance: Money
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                Image(.wallet)
                Text(verbatim: balance.compact).font(AppFont.bodyEmphasis)
            }
            .foregroundStyle(.ds.brandPrimary)
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.s)
            .background(Color.ds.brandAccentSoft, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
