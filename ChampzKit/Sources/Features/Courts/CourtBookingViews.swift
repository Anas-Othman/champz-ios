import SwiftUI

/// "BOOKING SUMMARY": the slot, booking details, friends to split with, the estimate, Continue.
public struct CourtBookingSummaryView: View {
    @State var viewModel: CourtBookingSummaryViewModel
    let makeFriendPicker: (_ max: Int, _ selected: [FriendCandidate]) -> FriendPickerViewModel

    public init(
        viewModel: CourtBookingSummaryViewModel,
        makeFriendPicker: @escaping (Int, [FriendCandidate]) -> FriendPickerViewModel
    ) {
        _viewModel = State(initialValue: viewModel)
        self.makeFriendPicker = makeFriendPicker
    }

    public var body: some View {
        LoadableView(viewModel.state, retry: { await viewModel.load() }) { _ in
            if let draft = viewModel.draft {
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.l) {
                        PurchaseHeaderCard(courtBooking: draft)
                        BookingInfoForm(
                            info: $viewModel.booking,
                            errors: viewModel.errors,
                            onEdit: viewModel.inputChanged
                        )
                        friends(draft)
                        OrderSummaryCard(price: draft.price, showsZeroFee: true)
                    }
                    .padding(Spacing.gutter)
                }
                .scrollDismissesKeyboard(.interactively)
                .safeAreaInset(edge: .bottom) {
                    TotalBar(
                        title: L10n.Common.continueKey,
                        total: draft.price.total,
                        isLoading: false,
                        action: viewModel.continueTapped
                    )
                }
            }
        }
        .background(Color.ds.backgroundMuted)
        .navigationTitle(Text(L10n.Court.bookingSummary))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $viewModel.isFriendPickerPresented) {
            FriendPickerSheet(viewModel: makeFriendPicker(
                CourtBookingSummaryViewModel.maxFriends,
                viewModel.friends
            )) { viewModel.setFriends($0) }
        }
        .task { await viewModel.load() }
    }

    /// COMING WITH A FRIEND? — adding friends splits the court equally.
    private func friends(_ draft: CourtBookingDraft) -> some View {
        FormCard(title: L10n.Court.comingWithAFriend) {
            ForEach(viewModel.friends) { friend in
                HStack(spacing: Spacing.m) {
                    AvatarView(url: friend.avatarUrl, name: friend.fullName, size: 36)
                    Text(verbatim: friend.fullName).font(AppFont.bodyEmphasis).foregroundStyle(.ds.textPrimary)
                    Spacer()
                    Button { viewModel.remove(friend) } label: {
                        Image(.close).foregroundStyle(.ds.textTertiary)
                    }
                    .accessibilityLabel(Text(L10n.Common.remove))
                }
            }
            Button { viewModel.isFriendPickerPresented = true } label: {
                Label { Text(L10n.Court.addPlayers) } icon: { Image(.plus) }
                    .font(AppFont.bodyEmphasis)
                    .foregroundStyle(.ds.brandPrimary)
            }
            .buttonStyle(.plain)
            if draft.isSplit {
                Text(L10n.Courts.splitExplainer).font(AppFont.caption).foregroundStyle(.ds.textSecondary)
                row(L10n.Court.yourPart, draft.hostShare.compact)
                row(L10n.Courts.friendsPay, draft.friendShare.compact)
            }
        }
    }

    private func row(_ label: LocalizedStringResource, _ value: String) -> some View {
        HStack {
            Text(label).font(AppFont.body).foregroundStyle(.ds.textSecondary)
            Spacer()
            Text(verbatim: value).font(AppFont.bodyEmphasis).foregroundStyle(.ds.textPrimary)
        }
    }
}

/// "CHECKOUT": the slot, payment options, policy, summary, pay bar.
public struct CourtBookingConfirmView: View {
    @State var viewModel: CourtBookingConfirmViewModel

    public init(viewModel: CourtBookingConfirmViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        let checkout = viewModel.checkout
        LoadableView(checkout.state, retry: { await checkout.load() }) { _ in
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    PurchaseHeaderCard(courtBooking: viewModel.draft)
                    PaymentOptionsCard(checkout: checkout)
                    if !checkout.policy.isEmpty {
                        CancellationPolicyCard(html: checkout.policy)
                    }
                    CheckoutSummaryCard(checkout: checkout)
                }
                .padding(Spacing.gutter)
            }
            .safeAreaInset(edge: .bottom) { CheckoutPayBar(checkout: checkout) }
        }
        .background(Color.ds.backgroundMuted)
        .navigationTitle(Text(L10n.Courts.checkout))
        .navigationBarTitleDisplayMode(.inline)
        .checkoutFlow(checkout)
    }
}
