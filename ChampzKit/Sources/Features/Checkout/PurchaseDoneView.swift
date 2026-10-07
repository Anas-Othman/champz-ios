import SwiftUI

/// The purple ticket shown after any paid flow: joining a match or tournament, topping up…
/// (friendly_match_registration_done_screen.dart, tournament_checkout_screen.dart, confirm_top_up_screen.dart).
/// Shows the server's figures, never an estimate.
public struct PurchaseDoneView: View {
    /// One "Label: value" line on the ticket.
    public struct Row: Hashable {
        let label: LocalizedStringResource
        let value: String

        public init(_ label: LocalizedStringResource, _ value: String) {
            self.label = label
            self.value = value
        }

        public static func == (lhs: Row, rhs: Row) -> Bool {
            lhs.label.key == rhs.label.key && lhs.value == rhs.value
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(label.key)
            hasher.combine(value)
        }
    }

    let title: String
    let rows: [Row]
    /// Date, venue… one line each under the divider.
    let details: [String]
    let toast: LocalizedStringResource?
    let backTitle: LocalizedStringResource
    let shareMessage: String?
    let onBack: () -> Void
    @Environment(ToastCenter.self) private var toasts

    public init(
        title: String,
        rows: [Row],
        details: [String],
        toast: LocalizedStringResource? = nil,
        backTitle: LocalizedStringResource,
        shareMessage: String? = nil,
        onBack: @escaping () -> Void
    ) {
        self.title = title
        self.rows = rows
        self.details = details
        self.toast = toast
        self.backTitle = backTitle
        self.shareMessage = shareMessage
        self.onBack = onBack
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                ticket
                AppButton(backTitle, style: .primary, action: onBack)
            }
            .padding(Spacing.gutter)
        }
        .background(Color.ds.backgroundMuted)
        .navigationBarBackButtonHidden() // it is paid; going back to "Pay" makes no sense
        .toolbar {
            if let shareMessage {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: shareMessage) { Image(.brandShare).resizable().frame(width: 20, height: 20) }
                }
            }
        }
        .onAppear {
            if let toast {
                toasts.show(Toast(.success, toast))
            }
        }
    }

    private var ticket: some View {
        TicketCard(title: title, rows: rows, details: details)
    }
}

/// The purple ticket: a check, the title, "Label: value" rows, a divider, detail lines.
/// Shown after paying, and again from "My History".
public struct TicketCard: View {
    let title: String
    let rows: [PurchaseDoneView.Row]
    let details: [String]

    public init(title: String, rows: [PurchaseDoneView.Row], details: [String]) {
        self.title = title
        self.rows = rows
        self.details = details
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Image(.checkCircle).font(AppFont.stateIcon).foregroundStyle(.ds.onBrand)
            Text(verbatim: title.uppercased()).font(AppFont.title2).foregroundStyle(.ds.onBrand)
            ForEach(rows, id: \.self) { line($0.label, $0.value) }
            Rectangle().fill(Color.ds.onBrand.opacity(0.4)).frame(height: 1).padding(.vertical, Spacing.s)
            ForEach(details.filter { !$0.isEmpty }, id: \.self) { line(nil, $0) }
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ds.brandPrimary, in: RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
    }

    private func line(_ label: LocalizedStringResource?, _ value: String) -> some View {
        HStack(spacing: Spacing.xs) {
            if let label {
                Text(label).font(AppFont.detailBody)
            }
            Text(verbatim: value).font(AppFont.bodyEmphasis)
        }
        .foregroundStyle(.ds.onBrand)
    }
}

public extension PurchaseDoneView.Row {
    /// "Registration: #Champz-000123" and "Amount: 32 QR" for a join.
    static func join(_ request: JoinRequest) -> [Self] {
        [
            Self(L10n.FriendlyMatch.registrationLabel, "#" + request.uniqueId),
            Self(L10n.Court.amountLabel, request.chargeMoney.compact),
        ]
    }
}
