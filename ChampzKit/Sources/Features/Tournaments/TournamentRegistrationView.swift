import SwiftUI

/// tournament_confirm_registration_screen.dart, built from the shared checkout components:
/// tournament header, booking details, payment options, order summary, pay bar.
public struct TournamentRegistrationView: View {
    @State var viewModel: TournamentRegistrationViewModel

    public init(viewModel: TournamentRegistrationViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        let checkout = viewModel.checkout
        LoadableView(checkout.state, retry: { await checkout.load() }) { _ in
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    PurchaseHeaderCard(tournament: viewModel.tournament)
                    BookingInfoForm(info: $viewModel.booking, errors: viewModel.errors, onEdit: viewModel.inputChanged)
                    PaymentOptionsCard(checkout: checkout)
                    CheckoutSummaryCard(checkout: checkout)
                }
                .padding(Spacing.gutter)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) { CheckoutPayBar(checkout: checkout) }
        }
        .background(Color.ds.backgroundMuted)
        .navigationTitle(Text(L10n.Tournament.confirmRegistration))
        .navigationBarTitleDisplayMode(.inline)
        .checkoutFlow(checkout)
        .task { await viewModel.prefill() }
    }
}
