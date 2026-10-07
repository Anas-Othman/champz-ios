import SwiftUI

/// "Payments" (payments_screen.dart): purple balance card with Top up, then TRANSACTIONS.
public struct WalletView: View {
    @Environment(DataChanges.self) private var changes: DataChanges?
    @State var viewModel: WalletViewModel

    public init(viewModel: WalletViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        LoadableView(viewModel.state, retry: { await viewModel.reload() }) { content in
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    BalanceCard(balance: content.balance, onTopUp: viewModel.topUp)
                    transactions(content.entries)
                }
                .padding(Spacing.gutter)
            }
            .refreshable { await viewModel.reload() }
        }
        .background(Color.ds.backgroundMuted)
        .navigationTitle(Text(L10n.Payment.payments))
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        // A top-up or a join moved money: show the new balance and row.
        .onChange(of: changes?.walletVersion) { Task { await viewModel.reload() } }
        .onChange(of: changes?.matchesVersion) { Task { await viewModel.reload() } }
        .onChange(of: changes?.tournamentsVersion) { Task { await viewModel.reload() } }
    }

    private func transactions(_ entries: [LedgerEntry]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L10n.Payment.transactions).textCase(.uppercase)
                .font(AppFont.sectionTitle)
                .foregroundStyle(.ds.textPrimary)
                .padding(.bottom, Spacing.s)
            if entries.isEmpty {
                Text(L10n.Payment.noPaymentHistoryFound)
                    .font(AppFont.detailBody)
                    .foregroundStyle(.ds.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.xxl)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(entries) { entry in
                        TransactionRow(entry: entry)
                            .task { await viewModel.loadMoreIfNeeded(after: entry) }
                        if entry.id != entries.last?.id {
                            Divider()
                        }
                    }
                    if viewModel.isLoadingMore {
                        ProgressView().padding(Spacing.l)
                    }
                }
            }
        }
        .padding(Spacing.l)
        .background(Color.ds.surface, in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
    }
}

/// Purple card: "Your Balance", the amount, and the Top up button.
struct BalanceCard: View {
    let balance: Money
    let onTopUp: () -> Void

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(L10n.Payment.yourBalance).font(AppFont.bodyLarge).foregroundStyle(.ds.brandAccentSoft)
                Text(verbatim: balance.compact).font(AppFont.title1).foregroundStyle(.ds.onBrand)
            }
            Spacer()
            Button(action: onTopUp) {
                HStack(spacing: Spacing.xs) {
                    Image(.plus)
                    Text(L10n.Payment.topUp)
                }
                .font(AppFont.bodyEmphasis)
                .foregroundStyle(.ds.brandPrimary)
                .padding(.horizontal, Spacing.l)
                .padding(.vertical, Spacing.s)
                .background(Color.ds.surface, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(Spacing.xl)
        .background(Color.ds.brandPrimary, in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
    }
}

/// Green up arrow for money in, red down arrow for money out; label, date, signed amount.
struct TransactionRow: View {
    let entry: LedgerEntry

    var body: some View {
        HStack(spacing: Spacing.m) {
            Image(entry.isCredit ? .arrowUp : .arrowDown)
                .font(.footnote.weight(.bold))
                .foregroundStyle(entry.isCredit ? Color.ds.statusSuccess : Color.ds.statusError)
                .frame(width: 40, height: 40)
                .background(Color.ds.surfaceMuted, in: Circle())
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(entry.reason.title).font(AppFont.bodyEmphasis).foregroundStyle(.ds.textPrimary)
                if let date = entry.date {
                    Text(verbatim: Self.format(date)).font(AppFont.caption).foregroundStyle(.ds.textSecondary)
                }
            }
            Spacer(minLength: Spacing.s)
            Text(verbatim: entry.signedText)
                .font(AppFont.bodyEmphasis)
                .foregroundStyle(entry.isCredit ? Color.ds.statusSuccess : Color.ds.textPrimary)
        }
        .padding(.vertical, Spacing.m)
        .accessibilityElement(children: .combine)
    }

    /// "7 Oct 2026 | 03:45 pm", in the phone's time zone.
    static func format(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "d MMM yyyy | hh:mm a"
        return formatter.string(from: date).replacingOccurrences(of: "AM", with: "am")
            .replacingOccurrences(of: "PM", with: "pm")
    }
}

extension LedgerReason {
    var title: LocalizedStringResource {
        switch self {
        case .matchFee: L10n.Wallet.reasonMatchFee
        case .tournamentServiceFee: L10n.Wallet.reasonTournamentServiceFee
        case .courtServiceFee: L10n.Wallet.reasonCourtServiceFee
        case .gameServiceFee: L10n.Wallet.reasonGameServiceFee
        case .bookCourt: L10n.Wallet.reasonBookCourt
        case .commission: L10n.Wallet.reasonCommission
        case .refund: L10n.Wallet.reasonRefund
        case .settlement: L10n.Wallet.reasonSettlement
        case .topup: L10n.Wallet.reasonTopup
        case .topupBonus: L10n.Wallet.reasonTopupBonus
        case .transfer: L10n.Wallet.reasonTransfer
        case .legacyImport: L10n.Wallet.reasonLegacyImport
        case .accountClosure: L10n.Wallet.reasonAccountClosure
        case .unclaimedCredit: L10n.Wallet.reasonUnclaimedCredit
        case .adminAdjustment: L10n.Wallet.reasonAdminAdjustment
        case .openingFloor: L10n.Wallet.reasonOpeningFloor
        case .openingAlignment: L10n.Wallet.reasonOpeningAlignment
        case .unknown: L10n.Wallet.reasonUnknown
        }
    }
}
