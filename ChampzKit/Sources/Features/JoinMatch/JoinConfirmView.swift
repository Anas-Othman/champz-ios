import SwiftUI

/// friendly_match_confirm_screen.dart, built from the shared checkout components.
public struct JoinConfirmView: View {
    @State var viewModel: JoinConfirmViewModel

    public init(viewModel: JoinConfirmViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        let checkout = viewModel.checkout
        LoadableView(checkout.state, retry: { await checkout.load() }) { _ in
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    PurchaseHeaderCard(match: viewModel.draft.match)
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
        .navigationTitle(Text(L10n.Court.bookingSummary))
        .navigationBarTitleDisplayMode(.inline)
        .checkoutFlow(checkout)
    }
}
