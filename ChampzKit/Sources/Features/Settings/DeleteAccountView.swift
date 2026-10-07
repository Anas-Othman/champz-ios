import SwiftUI

/// Delete account: what blocks it, what happens to the balance, the reactivation window, then a final confirm.
public struct DeleteAccountView: View {
    @State var viewModel: DeleteAccountViewModel

    public init(viewModel: DeleteAccountViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        LoadableView(viewModel.state, retry: { await viewModel.load() }) { state in
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    Text(verbatim: L10n.SettingsScreen.deleteExplainer(state.reactivationWindowDays))
                        .font(AppFont.detailBody)
                        .foregroundStyle(.ds.textSecondary)
                    if !state.blockers.isEmpty {
                        blockers(state.blockers)
                    }
                    if state.canDelete, !state.balance.isZero {
                        balance(state)
                    }
                }
                .padding(Spacing.gutter)
            }
            .safeAreaInset(edge: .bottom) {
                AppButton(
                    L10n.SettingsScreen.deleteConfirmButton,
                    style: .destructive,
                    isLoading: viewModel.isDeleting
                ) {
                    viewModel.isConfirmPresented = true
                }
                .disabled(!state.canDelete)
                .padding(Spacing.gutter)
                .background(Color.ds.backgroundMuted)
            }
        }
        .background(Color.ds.backgroundMuted)
        .navigationTitle(Text(L10n.Settings.deleteAccount))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            Text(L10n.SettingsScreen.deleteTitle),
            isPresented: $viewModel.isConfirmPresented,
            titleVisibility: .visible
        ) {
            Button(role: .destructive) { Task { await viewModel.delete() } } label: {
                Text(L10n.SettingsScreen.deleteConfirmButton)
            }
        } message: {
            Text(L10n.SettingsScreen.deleteFinal)
        }
        .task { await viewModel.load() }
    }

    /// Clubs I captain and upcoming fixtures, each named, so the player knows what to do first.
    private func blockers(_ items: [DeletionBlocker]) -> some View {
        FormCard(title: L10n.SettingsScreen.deleteTitle) {
            Text(L10n.SettingsScreen.deleteBlocked).font(AppFont.body).foregroundStyle(.ds.textSecondary)
            ForEach(Array(items.enumerated()), id: \.offset) { _, blocker in
                HStack(alignment: .top, spacing: Spacing.m) {
                    Image(blocker.isClub ? .team : .calendar).foregroundStyle(.ds.statusError)
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(blocker.isClub ? L10n.SettingsScreen.blockerClub : L10n.SettingsScreen.blockerFixture)
                            .font(AppFont.caption).foregroundStyle(.ds.textSecondary)
                        Text(verbatim: [blocker.label, blocker.on].filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(AppFont.bodyEmphasis).foregroundStyle(.ds.textPrimary)
                    }
                }
            }
        }
    }

    /// Keep it for the window, or give it to Champz.
    private func balance(_ state: DeletionState) -> some View {
        FormCard(title: L10n.SettingsScreen.balanceTitle) {
            Text(verbatim: state.balance.compact).font(AppFont.title2).foregroundStyle(.ds.brandPrimary)
            ForEach(BalanceDisposition.allCases, id: \.self) { option in
                Button { viewModel.disposition = option } label: {
                    HStack(alignment: .top, spacing: Spacing.m) {
                        Image(viewModel.disposition == option ? .checkCircle : .circle)
                            .foregroundStyle(viewModel.disposition == option ? Color.ds.brandPrimary : Color.ds
                                .controlUnselected)
                        Text(verbatim: option == .keep
                            ? L10n.SettingsScreen.dispositionKeep(state.reactivationWindowDays)
                            : String(localized: L10n.SettingsScreen.dispositionGive))
                            .font(AppFont.body)
                            .foregroundStyle(.ds.textPrimary)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(viewModel.disposition == option ? .isSelected : [])
            }
        }
    }
}
