import SwiftUI

/// Pick one item from a list: title, optional search, rows with a check on the current
/// choice, and a Select button. Used for nationality and position, and any future
/// "choose one of these" field.
public struct SelectionSheet<Item: Identifiable & Hashable>: View {
    private let title: LocalizedStringResource
    private let items: [Item]
    private let label: (Item) -> String
    private let searchPrompt: LocalizedStringResource?
    private let onSelect: (Item) -> Void

    @State private var choice: Item?
    @State private var query = ""
    @Environment(\.dismiss) private var dismiss

    /// - Parameter searchPrompt: shows a search field when set.
    public init(
        _ title: LocalizedStringResource,
        items: [Item],
        selection: Item?,
        searchPrompt: LocalizedStringResource? = nil,
        label: @escaping (Item) -> String,
        onSelect: @escaping (Item) -> Void
    ) {
        self.title = title
        self.items = items
        self.label = label
        self.searchPrompt = searchPrompt
        self.onSelect = onSelect
        _choice = State(initialValue: selection)
    }

    private var results: [Item] {
        guard !query.isEmpty else { return items }
        return items.filter { label($0).localizedCaseInsensitiveContains(query) }
    }

    public var body: some View {
        NavigationStack {
            List(results) { item in
                Button { choice = item } label: {
                    HStack {
                        Text(verbatim: label(item))
                            .font(AppFont.bodyLarge)
                            .foregroundStyle(item == choice ? Color.ds.brandPrimary : Color.ds.textPrimary)
                        Spacer()
                        if item == choice {
                            Image(.check).foregroundStyle(.ds.brandPrimary)
                        }
                    }
                }
                .accessibilityAddTraits(item == choice ? .isSelected : [])
            }
            .listStyle(.plain)
            .modifier(SearchableIf(prompt: searchPrompt, query: $query))
            .navigationTitle(Text(title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(.close) }
                }
            }
            .safeAreaInset(edge: .bottom) {
                AppButton(L10n.TransferMarket.select, style: .primary) {
                    if let choice {
                        onSelect(choice)
                    }
                    dismiss()
                }
                .disabled(choice == nil)
                .padding(Spacing.gutter)
                .background(Color.ds.background)
            }
        }
    }
}

/// `.searchable` only when a prompt is given.
private struct SearchableIf: ViewModifier {
    let prompt: LocalizedStringResource?
    @Binding var query: String

    func body(content: Content) -> some View {
        if let prompt {
            content.searchable(text: $query, prompt: Text(prompt))
        } else {
            content
        }
    }
}

/// A form row that opens a picker: label above, the value (or a grey placeholder) and a
/// purple chevron in a bordered box, error below. Date of birth, nationality, position…
public struct PickerField: View {
    private let label: LocalizedStringResource
    private let value: String?
    private let placeholder: LocalizedStringResource
    private let error: String?
    private let action: () -> Void

    public init(
        _ label: LocalizedStringResource,
        value: String?,
        placeholder: LocalizedStringResource,
        error: String? = nil,
        action: @escaping () -> Void
    ) {
        self.label = label
        self.value = value
        self.placeholder = placeholder
        self.error = error
        self.action = action
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label).font(AppFont.caption).foregroundStyle(.ds.textSecondary)
            Button(action: action) {
                HStack {
                    if let value, !value.isEmpty {
                        Text(verbatim: value).foregroundStyle(.ds.textPrimary)
                    } else {
                        Text(placeholder).foregroundStyle(.ds.textTertiary)
                    }
                    Spacer()
                    Image(.chevronDown).font(.caption).foregroundStyle(.ds.brandPrimary)
                }
                .font(AppFont.bodyLarge)
                .padding(.horizontal, Spacing.l)
                .frame(height: ControlSize.field)
                .background(Color.ds.surface, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                        .strokeBorder(error == nil ? Color.ds.border : Color.ds.statusError, lineWidth: 1)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if let error {
                Text(verbatim: error).font(AppFont.caption).foregroundStyle(.ds.statusError)
            }
        }
    }
}
