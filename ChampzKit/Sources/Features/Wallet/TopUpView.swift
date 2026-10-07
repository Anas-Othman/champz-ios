import SwiftUI

/// "TOP UP" (top_up_screen.dart): big amount field, Quick Add, the bonus, payment method, pay bar.
public struct TopUpView: View {
    @State var viewModel: TopUpViewModel
    @FocusState private var isAmountFocused: Bool

    public init(viewModel: TopUpViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        let checkout = viewModel.checkout
        LoadableView(checkout.state, retry: { await checkout.load() }) { _ in
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    amountCard
                    PaymentOptionsCard(checkout: checkout)
                    if let amount = viewModel.amount {
                        OrderSummaryCard(rows: summaryRows(amount))
                    }
                }
                .padding(Spacing.gutter)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) { CheckoutPayBar(checkout: checkout) }
        }
        .background(Color.ds.backgroundMuted)
        .navigationTitle(Text(verbatim: String(localized: L10n.Payment.topUp).uppercased()))
        .navigationBarTitleDisplayMode(.inline)
        .checkoutFlow(checkout)
        // Ask for the bonus a moment after typing stops, not on every keystroke.
        .task(id: viewModel.amountText) {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await viewModel.refreshBonus()
        }
    }

    private var amountCard: some View {
        FormCard(title: L10n.Payment.enterAmount) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                TextField(text: $viewModel.amountText) { Text(verbatim: "0").foregroundStyle(.ds.textTertiary) }
                    .font(AppFont.display)
                    .foregroundStyle(.ds.textPrimary)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .focused($isAmountFocused)
                    .fixedSize()
                Text(verbatim: Money.zero(Money.defaultCurrency).currencyLabel)
                    .font(AppFont.title2)
                    .foregroundStyle(.ds.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.m)
            .contentShape(Rectangle())
            .onTapGesture { isAmountFocused = true }
            Text(L10n.Payment.quickAdd).font(AppFont.caption).foregroundStyle(.ds.textSecondary)
            HStack(spacing: Spacing.s) {
                ForEach(TopUpViewModel.presets, id: \.self) { preset in
                    Button { viewModel.quickAdd(preset) } label: {
                        Text(verbatim: "+" + Money(preset, currency: Money.defaultCurrency).compact)
                            .font(AppFont.bodyEmphasis)
                            .foregroundStyle(.ds.brandPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(Color.ds.brandAccentSoft, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// Amount, the bonus when this amount earns one, and what lands in the wallet.
    private func summaryRows(_ amount: Money) -> [OrderSummaryCard.Row] {
        var rows = [OrderSummaryCard.Row(label: L10n.Payment.amount, value: amount.compact)]
        if let bonus = viewModel.bonus, bonus.hasBonus {
            rows.append(OrderSummaryCard.Row(label: L10n.Payment.bonusAmount, value: "+ " + bonus.bonusMoney.compact))
            rows.append(OrderSummaryCard.Row(label: L10n.Wallet.youWillGet, value: bonus.totalMoney.compact))
        }
        return rows
    }
}
