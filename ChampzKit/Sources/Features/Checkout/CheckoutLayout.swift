import SwiftUI

// Layout pieces shared by checkout-style screens (registration, booking summary…).

/// White card with an 18pt bold title and an optional pill next to it.
public struct FormCard<Content: View>: View {
    let title: LocalizedStringResource
    let badge: LocalizedStringResource?
    let content: Content

    public init(
        title: LocalizedStringResource,
        badge: LocalizedStringResource? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.badge = badge
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack(spacing: Spacing.s) {
                Text(title).font(AppFont.sectionTitle).foregroundStyle(.ds.textPrimary)
                if let badge {
                    Text(badge)
                        .font(AppFont.captionSmall)
                        .foregroundStyle(.ds.textSecondary)
                        .padding(.horizontal, Spacing.s).padding(.vertical, Spacing.xxs)
                        .background(Color.ds.surfaceMuted, in: Capsule())
                }
            }
            content
        }
        .padding(Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: Radius.l, style: .continuous)
                .fill(Color.ds.surface)
                .shadow(color: .ds.shadow, radius: 5, y: 2)
        }
    }
}

/// "Booking Information": name, email, phone with country code. Bind it to a `BookingInfo`.
public struct BookingInfoForm: View {
    @Binding var info: BookingInfo
    let errors: [BookingInfo.Field: String]
    let onEdit: (BookingInfo.Field) -> Void

    public init(
        info: Binding<BookingInfo>,
        errors: [BookingInfo.Field: String],
        onEdit: @escaping (BookingInfo.Field) -> Void
    ) {
        _info = info
        self.errors = errors
        self.onEdit = onEdit
    }

    public var body: some View {
        FormCard(title: L10n.FriendlyMatch.bookingInformation) {
            AppTextField(
                L10n.FriendlyMatch.enterYourFullName,
                text: $info.name,
                error: errors[.name],
                contentType: .name,
                autocapitalization: .words
            )
            .onChange(of: info.name) { onEdit(.name) }
            AppTextField(
                L10n.FriendlyMatch.enterYourEmail,
                text: $info.email,
                error: errors[.email],
                keyboard: .emailAddress,
                contentType: .emailAddress,
                autocapitalization: .never
            )
            .onChange(of: info.email) { onEdit(.email) }
            AppTextField(
                L10n.FriendlyMatch.enterYourPhoneNumber,
                text: $info.phone,
                error: errors[.phone],
                keyboard: .phonePad,
                contentType: .telephoneNumber
            ) {
                CountryDialCodePicker(selection: $info.country)
            }
            .onChange(of: info.phone) {
                if info.phone.count > BookingInfo
                    .phoneLength
                {
                    info.phone = String(info.phone.prefix(BookingInfo.phoneLength))
                }
                onEdit(.phone)
            }
        }
    }
}

/// Checkbox row: title, subtitle, price on the right. Disabled rows are dimmed.
public struct CheckRow: View {
    let title: LocalizedStringResource
    let subtitle: String
    let price: String
    let isOn: Bool
    let isEnabled: Bool
    let onToggle: () -> Void
    let onTap: () -> Void

    public init(
        title: LocalizedStringResource,
        subtitle: String,
        price: String,
        isOn: Bool,
        isEnabled: Bool,
        onToggle: @escaping () -> Void,
        onTap: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.price = price
        self.isOn = isOn
        self.isEnabled = isEnabled
        self.onToggle = onToggle
        self.onTap = onTap
    }

    public var body: some View {
        HStack(spacing: Spacing.m) {
            Button(action: onToggle) {
                Image(isOn ? .checkSquare : .square)
                    .font(.title3)
                    .foregroundStyle(isOn ? Color.ds.brandPrimary : Color.ds.controlUnselected)
            }
            Button(action: onTap) {
                HStack {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(title).font(AppFont.bodyEmphasis).foregroundStyle(.ds.textPrimary)
                        Text(verbatim: subtitle).font(AppFont.caption).foregroundStyle(.ds.textSecondary).lineLimit(1)
                    }
                    Spacer()
                    Text(verbatim: price).font(AppFont.bodyEmphasis).foregroundStyle(.ds.brandPrimary)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
    }
}

/// "Order Summary" with label/value rows.
public struct OrderSummaryCard: View {
    public struct Row: Identifiable {
        let label: LocalizedStringResource
        let value: String
        public var id: String {
            label.key
        }

        public init(label: LocalizedStringResource, value: String) {
            self.label = label
            self.value = value
        }
    }

    let rows: [Row]

    public init(rows: [Row]) {
        self.rows = rows
    }

    /// Subtotal and service fee, before the player has chosen how to pay.
    /// `showsZeroFee`: the registration screen always lists the fee, even at 0 (current app).
    public init(price: PriceBreakdown, showsZeroFee: Bool = false) {
        var rows = [Row(label: L10n.Team.subtotal, value: price.subtotal.compact)]
        if showsZeroFee || !price.fee.isZero {
            rows.append(Row(label: L10n.Team.serviceFee, value: price.fee.compact))
        }
        self.rows = rows
    }

    public var body: some View {
        FormCard(title: L10n.Court.orderSummary) {
            ForEach(rows) { row in
                HStack {
                    Text(row.label).font(AppFont.detailBody).foregroundStyle(.ds.textSecondary)
                    Spacer()
                    Text(verbatim: row.value).font(AppFont.bodyEmphasis).foregroundStyle(.ds.textPrimary)
                }
            }
        }
    }
}

/// Sticky bottom bar: the action on the left, the total on the right with "TOTAL" under it.
public struct TotalBar: View {
    let title: LocalizedStringResource
    let total: Money
    let isLoading: Bool
    let action: () -> Void

    public init(title: LocalizedStringResource, total: Money, isLoading: Bool, action: @escaping () -> Void) {
        self.title = title
        self.total = total
        self.isLoading = isLoading
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack {
                Text(title).font(AppFont.buttonLarge)
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text(verbatim: total.compact).font(AppFont.buttonLarge)
                    Text(L10n.FriendlyMatch.total).font(AppFont.captionSmall)
                }
            }
            .foregroundStyle(.ds.onBrand)
            .padding(.horizontal, Spacing.xl)
            .frame(height: 60)
            .background(Color.ds.brandPrimary, in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
            .overlay {
                if isLoading {
                    ProgressView().tint(.ds.onBrand)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .padding(.horizontal, Spacing.xl)
        .padding(.vertical, Spacing.m)
        .background(Color.ds.backgroundMuted)
    }
}
