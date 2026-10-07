import SwiftUI

// The small choosers on the venue page: day cards, pills, court options.

/// "THU / 5 / MAR".
struct DayCard: View {
    let day: Date
    let isSelected: Bool
    let action: () -> Void

    private static func format(_ date: Date, _ pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = pattern
        return formatter.string(from: date).uppercased()
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.xxs) {
                Text(verbatim: Self.format(day, "EEE")).font(AppFont.captionSmall)
                Text(verbatim: Self.format(day, "d")).font(AppFont.title2)
                Text(verbatim: Self.format(day, "MMM")).font(AppFont.captionSmall)
            }
            .foregroundStyle(isSelected ? Color.ds.onBrand : Color.ds.textPrimary)
            .frame(width: 60, height: 76)
            .background(
                isSelected ? Color.ds.brandPrimary : Color.ds.surface,
                in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// A rounded choice: purple when selected, struck grey when taken.
struct Pill: View {
    let text: String
    let isSelected: Bool
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(verbatim: text)
                .font(AppFont.bodyEmphasis)
                .strikethrough(!isEnabled)
                .foregroundStyle(isSelected ? Color.ds
                    .onBrand : (isEnabled ? Color.ds.textPrimary : Color.ds.textTertiary))
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(
                    isSelected ? Color.ds.brandPrimary : Color.ds.surface,
                    in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// A wrapping row of pills for numbers (durations).
struct PillRow: View {
    let items: [Int]
    let selected: Int?
    let title: (Int) -> String
    let onSelect: (Int) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: Spacing.s)], spacing: Spacing.s) {
            ForEach(items, id: \.self) { item in
                Pill(text: title(item), isSelected: item == selected) { onSelect(item) }
            }
        }
    }
}

/// A court for the chosen window: name, surface, price, radio check.
struct CourtOption: View {
    let court: PricedCourt
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.m) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(verbatim: court.name).font(AppFont.infoValue).foregroundStyle(.ds.textPrimary)
                    if !court.courtType.isEmpty {
                        Text(verbatim: court.courtType).font(AppFont.caption).foregroundStyle(.ds.textSecondary)
                    }
                }
                Spacer()
                Text(verbatim: court.priceMoney.compact).font(AppFont.infoValue).foregroundStyle(.ds.brandPrimary)
                Image(isSelected ? .checkCircle : .circle)
                    .foregroundStyle(isSelected ? Color.ds.brandPrimary : Color.ds.controlUnselected)
            }
            .padding(Spacing.l)
            .background(Color.ds.surface, in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.l, style: .continuous)
                    .strokeBorder(isSelected ? Color.ds.brandPrimary : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
