import SwiftUI

/// A court invite: the booking, who invited me, my share, then pay (shared checkout) or decline.
public struct BookingInviteView: View {
    @State var viewModel: BookingInviteViewModel

    public init(viewModel: BookingInviteViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        let checkout = viewModel.checkout
        LoadableView(viewModel.state, retry: { await viewModel.load() }) { content in
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    PurchaseHeaderCard(booking: content.booking)
                    if let host = content.booking.owner {
                        FormCard(title: L10n.Notifications.invitedBy) {
                            HStack(spacing: Spacing.m) {
                                AvatarView(url: "", name: host.name, size: 40)
                                Text(verbatim: host.name).font(AppFont.bodyEmphasis).foregroundStyle(.ds.textPrimary)
                            }
                        }
                    }
                    switch content.answer {
                    case .open:
                        PaymentOptionsCard(checkout: checkout)
                        if !checkout.policy.isEmpty {
                            CancellationPolicyCard(html: checkout.policy)
                        }
                        OrderSummaryCard(rows: [.init(
                            label: L10n.Notifications.yourShare,
                            value: content.booking.payable.compact
                        )])
                        Button(role: .destructive) { viewModel.isDeclineConfirmPresented = true } label: {
                            Text(L10n.Notifications.decline).font(AppFont.bodyEmphasis).frame(maxWidth: .infinity)
                        }
                        .disabled(viewModel.isDeclining)
                    case .accepted:
                        StatusNote(
                            text: L10n.Notifications.inviteAccepted,
                            icon: .checkCircle,
                            color: .ds.statusSuccess
                        )
                    case .declined:
                        StatusNote(text: L10n.Notifications.inviteDeclinedState, icon: .info, color: .ds.textSecondary)
                    case .notInvited:
                        StatusNote(text: L10n.Notifications.notInvited, icon: .warning, color: .ds.textSecondary)
                    }
                }
                .padding(Spacing.gutter)
            }
            .safeAreaInset(edge: .bottom) {
                if content.answer == .open {
                    CheckoutPayBar(checkout: checkout)
                }
            }
        }
        .background(Color.ds.backgroundMuted)
        .navigationTitle(Text(L10n.Notifications.courtInvite))
        .navigationBarTitleDisplayMode(.inline)
        .checkoutFlow(checkout)
        .confirmationDialog(
            Text(L10n.Notifications.declineTitle),
            isPresented: $viewModel.isDeclineConfirmPresented,
            titleVisibility: .visible
        ) {
            Button(role: .destructive) { Task { await viewModel.confirmDecline() } } label: {
                Text(L10n.Notifications.decline)
            }
        } message: {
            Text(L10n.Notifications.declineMessage)
        }
        .task { await viewModel.load() }
    }
}

/// An icon and a sentence in a white card: the state of something already settled.
struct StatusNote: View {
    let text: LocalizedStringResource
    let icon: AppIcon
    let color: Color

    var body: some View {
        HStack(spacing: Spacing.m) {
            Image(icon).foregroundStyle(color)
            Text(text).font(AppFont.bodyEmphasis).foregroundStyle(.ds.textPrimary)
        }
        .padding(Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ds.surface, in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
    }
}
