import SwiftUI

/// "FILTER": position chips, nationality, age range, then Apply. Reset clears the sheet's filters.
/// Edits stay local until Apply, so closing the sheet changes nothing.
struct MarketFilterSheet: View {
    let positions: [Position]
    let nationalities: [Nationality]
    let onApply: (MarketFilter) -> Void

    @State private var draft: MarketFilter
    @State private var ages: ClosedRange<Int>
    @State private var isPickingNationality = false
    @Environment(\.dismiss) private var dismiss

    init(
        filter: MarketFilter,
        positions: [Position],
        nationalities: [Nationality],
        onApply: @escaping (MarketFilter) -> Void
    ) {
        self.positions = positions
        self.nationalities = nationalities
        self.onApply = onApply
        _draft = State(initialValue: filter)
        _ages = State(initialValue: filter.ages ?? MarketFilter.ageBounds)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    section(L10n.Profile.position) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Spacing.s) {
                                FilterChip(L10n.Market.allPositions, isSelected: draft.position == nil) {
                                    draft.position = nil
                                }
                                ForEach(positions) { position in
                                    FilterChip(
                                        LocalizedStringResource(stringLiteral: position.name),
                                        isSelected: draft.position?.id == position.id
                                    ) {
                                        // Tapping the selected one again clears it.
                                        draft.position = draft.position?.id == position.id ? nil : position
                                    }
                                }
                            }
                        }
                    }
                    PickerField(
                        L10n.Profile.nationality,
                        value: draft.nationality?.label,
                        placeholder: L10n.Market.anyNationality
                    ) { isPickingNationality = true }
                    section(L10n.TransferMarket.age) {
                        Text(verbatim: ages == MarketFilter.ageBounds
                            ? String(localized: L10n.Market.anyAge)
                            : L10n.Market.ageRange(ages.lowerBound, ages.upperBound))
                            .font(AppFont.bodyEmphasis)
                            .foregroundStyle(.ds.brandPrimary)
                        RangeSlider(range: $ages, in: MarketFilter.ageBounds)
                    }
                }
                .padding(Spacing.gutter)
            }
            .navigationTitle(Text(L10n.Market.filter))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(.close) }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        draft = draft.clearingSheetFilters()
                        ages = MarketFilter.ageBounds
                    } label: { Text(L10n.Market.reset) }
                        .disabled(draft.activeCount == 0 && ages == MarketFilter.ageBounds)
                }
            }
            .safeAreaInset(edge: .bottom) {
                AppButton(L10n.TransferMarket.applyFilter, style: .primary) {
                    var filter = draft
                    // The full range means "any age", so nothing is sent.
                    filter.ages = ages == MarketFilter.ageBounds ? nil : ages
                    onApply(filter)
                    dismiss()
                }
                .padding(Spacing.gutter)
                .background(Color.ds.background)
            }
            .sheet(isPresented: $isPickingNationality) {
                SelectionSheet(
                    L10n.Profile.nationality,
                    items: nationalities,
                    selection: draft.nationality,
                    searchPrompt: L10n.Market.nationalityPrompt,
                    label: \.label
                ) { draft.nationality = $0 }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func section(_ title: LocalizedStringResource, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(title).font(AppFont.caption).foregroundStyle(.ds.textSecondary)
            content()
        }
    }
}
