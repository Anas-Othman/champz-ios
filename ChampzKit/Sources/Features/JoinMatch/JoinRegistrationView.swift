import SwiftUI

/// friendly_match_registration_screen.dart: match card, booking info, add player, order summary, Continue.
public struct JoinRegistrationView: View {
    @State var viewModel: JoinRegistrationViewModel
    let makeFriendPicker: (_ max: Int, _ selected: [FriendCandidate]) -> FriendPickerViewModel

    public init(
        viewModel: JoinRegistrationViewModel,
        makeFriendPicker: @escaping (Int, [FriendCandidate]) -> FriendPickerViewModel
    ) {
        _viewModel = State(initialValue: viewModel)
        self.makeFriendPicker = makeFriendPicker
    }

    public var body: some View {
        LoadableView(viewModel.state, retry: { await viewModel.load() }) { match in
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    PurchaseHeaderCard(match: match)
                    BookingInfoForm(info: $viewModel.booking, errors: viewModel.errors, onEdit: viewModel.inputChanged)
                    addPlayer(match)
                    OrderSummaryCard(price: viewModel.price, showsZeroFee: true)
                }
                .padding(Spacing.gutter)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) {
                TotalBar(
                    title: L10n.Common.continueKey,
                    total: viewModel.total,
                    isLoading: false,
                    action: viewModel.continueTapped
                )
            }
        }
        .background(Color.ds.backgroundMuted)
        .navigationTitle(Text(viewModel.isWaitingList ? L10n.FriendlyMatch.joinWaitingListTitle : L10n.FriendlyMatch
                .joinMatch))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $viewModel.isFriendPickerPresented) {
            FriendPickerSheet(viewModel: makeFriendPicker(viewModel.maxFriends, viewModel.friends)) { picked in
                viewModel.setFriends(picked)
            }
        }
        .task { await viewModel.load() }
    }

    private func addPlayer(_ match: Match) -> some View {
        FormCard(title: L10n.FriendlyMatch.addPlayer, badge: L10n.FriendlyMatch.optional) {
            if viewModel.remainingSlots <= 1 {
                Text(L10n.FriendlyMatch.noExtraSlotsAvailable).font(AppFont.caption).foregroundStyle(.ds.statusError)
            } else if viewModel.remainingSlots == 2 {
                Text(L10n.FriendlyMatch.oneExtraSlotAvailable).font(AppFont.caption).foregroundStyle(.ds.textSecondary)
            }
            CheckRow(
                title: L10n.Join.payForAFriend,
                subtitle: friendsSubtitle,
                price: "+" + Money(
                    viewModel.unitPrice.amount * Decimal(max(1, viewModel.friends.count)),
                    currency: viewModel.unitPrice.currency
                ).compact,
                isOn: !viewModel.friends.isEmpty,
                isEnabled: viewModel.canAddFriends,
                onToggle: viewModel.toggleFriends,
                onTap: { viewModel.isFriendPickerPresented = true }
            )
            CheckRow(
                title: L10n.Join.payForAGuest,
                subtitle: String(localized: L10n.Join.payForAGuestSubtitle),
                price: "+" + viewModel.unitPrice.compact,
                isOn: viewModel.isGuestSelected,
                isEnabled: viewModel.canAddGuest,
                onToggle: { viewModel.isGuestSelected.toggle() },
                onTap: { viewModel.isGuestSelected.toggle() }
            )
            if viewModel.isGuestSelected {
                AppTextField(
                    L10n.FriendlyMatch.enterGuestEmail,
                    text: $viewModel.guestEmail,
                    error: viewModel.guestEmailError,
                    keyboard: .emailAddress,
                    contentType: .emailAddress,
                    autocapitalization: .never
                )
                .onChange(of: viewModel.guestEmail) { viewModel.guestEmailChanged() }
            }
        }
    }

    private var friendsSubtitle: String {
        switch viewModel.friends.count {
        case 0: String(localized: L10n.Join.payForAFriendSubtitle)
        case 1: viewModel.friends[0].fullName
        default: L10n.Join.playersSelected(viewModel.friends.count)
        }
    }
}
