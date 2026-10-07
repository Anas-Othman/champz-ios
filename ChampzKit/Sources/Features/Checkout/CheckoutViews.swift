import AuthenticationServices
import SwiftUI

// Payment UI shared by every paid flow. A screen composes:
//   PaymentOptionsCard(checkout:) · CancellationPolicyCard · OrderSummaryCard · CheckoutPayBar(checkout:)
// and attaches `.checkoutFlow(checkout)` once for the split sheet and the hosted card page.

/// "Payment Method": cash (when allowed), card, and "Use my balance".
public struct PaymentOptionsCard: View {
    @Bindable var checkout: Checkout

    public init(checkout: Checkout) {
        self.checkout = checkout
    }

    public var body: some View {
        FormCard(title: L10n.Payment.paymentMethod) {
            if checkout.isCashAvailable {
                PaymentMethodRow(
                    icon: .cash,
                    title: L10n.Tournament.payWithCash,
                    isSelected: checkout.method == .cash
                ) {
                    checkout.method = .cash
                }
            }
            if checkout.isApplePayAvailable {
                PaymentMethodRow(
                    icon: .applePay,
                    title: L10n.Team.applePay,
                    isSelected: checkout.method == .applePay
                ) {
                    checkout.method = .applePay
                }
            }
            PaymentMethodRow(
                icon: .wallet,
                title: L10n.Payment.payViaCreditDebitCard,
                trailing: L10n.FriendlyMatch.online,
                isSelected: checkout.method == .card
            ) {
                checkout.method = .card
            }
            if checkout.allowsWallet {
                WalletToggleRow(checkout: checkout)
            }
        }
    }
}

/// "USE MY BALANCE" with the balance and a one-line explanation of what it will do.
public struct WalletToggleRow: View {
    @Bindable var checkout: Checkout

    public init(checkout: Checkout) {
        self.checkout = checkout
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Toggle(isOn: $checkout.useWallet) {
                HStack {
                    Text(L10n.Court.useMyBalance).font(AppFont.bodyEmphasis).foregroundStyle(.ds.textPrimary)
                    Spacer()
                    Text(verbatim: checkout.balance.compact)
                        .font(AppFont.bodyEmphasis)
                        .foregroundStyle(checkout.canUseWallet ? Color.ds.brandPrimary : Color.ds.textTertiary)
                }
            }
            .tint(.ds.brandPrimary)
            .disabled(!checkout.canUseWallet)
            Group {
                if !checkout.canUseWallet {
                    Text(L10n.Court.insufficientForBooking).foregroundStyle(.ds.statusError)
                } else if checkout.walletCoversAll {
                    Text(verbatim: String(localized: L10n.Team.remainingAfterPayment) + ": " +
                        (checkout.balance - checkout.total).compact)
                        .foregroundStyle(.ds.textSecondary)
                } else if checkout.isSplit {
                    Text(L10n.Join.splitDecidedAtPayment).foregroundStyle(.ds.textSecondary)
                }
            }
            .font(AppFont.caption)
        }
        .padding(.top, Spacing.xs)
    }
}

/// Radio row for one payment method.
public struct PaymentMethodRow: View {
    let icon: AppIcon
    let title: LocalizedStringResource
    var trailing: LocalizedStringResource?
    let isSelected: Bool
    let action: () -> Void

    public init(
        icon: AppIcon,
        title: LocalizedStringResource,
        trailing: LocalizedStringResource? = nil,
        isSelected: Bool,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.trailing = trailing
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.m) {
                Image(icon).foregroundStyle(.ds.brandPrimary)
                Text(title).font(AppFont.bodyEmphasis).foregroundStyle(.ds.textPrimary)
                Spacer()
                if let trailing {
                    Text(trailing).font(AppFont.caption).foregroundStyle(.ds.textSecondary)
                }
                Image(isSelected ? .checkCircle : .circle)
                    .foregroundStyle(isSelected ? Color.ds.brandPrimary : Color.ds.controlUnselected)
            }
            .padding(Spacing.m)
            .background(Color.ds.surfaceMuted, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// The sticky pay button: shows what is left to pay and the right verb.
public struct CheckoutPayBar: View {
    let checkout: Checkout

    public init(checkout: Checkout) {
        self.checkout = checkout
    }

    public var body: some View {
        if let session = checkout.applePaySession {
            ApplePayBar(checkout: checkout, session: session)
        } else {
            TotalBar(title: title, total: checkout.amountToPay, isLoading: checkout.isSubmitting) {
                Task { await checkout.pay() }
            }
        }
    }

    private var title: LocalizedStringResource {
        if checkout.isSubmitting {
            return L10n.FriendlyMatch.processing
        }
        return checkout.completesImmediately ? L10n.Team.joinNow : L10n.Payment.payNow
    }
}

/// The order summary on a payment screen: subtotal, service fee when there is one, and
/// "From Wallet" once the balance covers the whole purchase. A split is not listed here:
/// the server decides it and the confirmation sheet shows its numbers.
public struct CheckoutSummaryCard: View {
    let checkout: Checkout

    public init(checkout: Checkout) {
        self.checkout = checkout
    }

    public var body: some View {
        OrderSummaryCard(rows: rows)
    }

    var rows: [OrderSummaryCard.Row] {
        var rows = OrderSummaryCard(price: checkout.price).rows
        if checkout.walletCoversAll {
            rows.append(OrderSummaryCard.Row(label: L10n.Court.fromWallet, value: "- " + checkout.total.compact))
        }
        return rows
    }
}

/// Booking cancellation policy: two lines and "Read More".
public struct CancellationPolicyCard: View {
    let html: String
    @State private var isExpanded = false

    public init(html: String) {
        self.html = html
    }

    public var body: some View {
        FormCard(title: L10n.Court.bookingCancellationPolicy) {
            Text(verbatim: html.strippingHTML).font(AppFont.detailBody).foregroundStyle(.ds.textSecondary).lineLimit(2)
            Button { isExpanded = true } label: {
                Text(L10n.Court.readMore).font(AppFont.bodyEmphasis).foregroundStyle(.ds.brandPrimary)
            }
        }
        .sheet(isPresented: $isExpanded) {
            NavigationStack {
                ScrollView {
                    Text(verbatim: html.strippingHTML).font(AppFont.detailBody).foregroundStyle(.ds.textSecondary)
                        .padding(Spacing.gutter)
                }
                .navigationTitle(Text(L10n.Court.bookingCancellationPolicy))
                .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.medium, .large])
        }
    }
}

public extension View {
    /// Attach once per checkout screen: shows the server's split for confirmation and runs the hosted card page.
    func checkoutFlow(_ checkout: Checkout) -> some View {
        modifier(CheckoutFlowModifier(checkout: checkout))
    }
}

private struct CheckoutFlowModifier: ViewModifier {
    @Bindable var checkout: Checkout
    @Environment(\.webAuthenticationSession) private var webAuthenticationSession

    func body(content: Content) -> some View {
        content
            .sheet(item: $checkout.splitToConfirm) { split in
                SplitConfirmSheet(split: split) { Task { await checkout.payOnline(useWallet: true) } }
            }
            // ASWebAuthenticationSession returns when SkipCash redirects to champz:// or the player closes it.
            .task(id: checkout.pendingCheckout?.id) {
                guard let payment = checkout.pendingCheckout, let url = URL(string: payment.payUrl) else { return }
                let callback = try? await webAuthenticationSession.authenticate(
                    using: url,
                    callbackURLScheme: "champz",
                    preferredBrowserSession: .ephemeral
                )
                await checkout.checkoutFinished(callback: callback)
            }
            .alert(Text(L10n.Checkout.paymentProcessingTitle), isPresented: $checkout.isProcessingNoticePresented) {
                Button { checkout.processingAcknowledged() } label: { Text(L10n.Common.ok) }
            } message: {
                Text(L10n.Checkout.paymentProcessingMessage)
            }
            .task { await checkout.load() }
            // Leaving with a live, unpaid Apple Pay session releases it (and the pending order).
            .onDisappear { Task { await checkout.cancelApplePay() } }
    }
}

/// The server's split, shown before the card page opens.
struct SplitConfirmSheet: View {
    let split: SplitPreview
    let onContinue: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            Text(L10n.Join.confirmPayment).font(AppFont.title2).foregroundStyle(.ds.textPrimary)
            Text(verbatim: message).font(AppFont.body).foregroundStyle(.ds.textSecondary)
            Spacer(minLength: 0)
            AppButton(L10n.Join.continueToCard, style: .primary) {
                dismiss()
                onContinue()
            }
        }
        .padding(Spacing.xl)
        .presentationDetents([.height(260)])
    }

    private var message: String {
        let card = Money(split.fromCard, currency: Money.defaultCurrency).compact
        guard split.isSplit else { return L10n.Join.cardPaysAll(card) }
        return L10n.Join.splitSummary(Money(split.fromWallet, currency: Money.defaultCurrency).compact, card)
    }
}
