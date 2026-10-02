import SwiftUI

/// Plain-text tab switcher (PHONE NUMBER · EMAIL) as in the current app: the selected
/// tab in brand accent, the others dimmed. Generic over any `Hashable` selection.
public struct TextTab<Value: Hashable>: Identifiable {
    public let value: Value
    public let title: LocalizedStringResource

    public var id: Value {
        value
    }

    public init(_ value: Value, _ title: LocalizedStringResource) {
        self.value = value
        self.title = title
    }
}

public struct TextTabs<Value: Hashable>: View {
    @Binding private var selection: Value
    private let tabs: [TextTab<Value>]

    public init(selection: Binding<Value>, tabs: [TextTab<Value>]) {
        _selection = selection
        self.tabs = tabs
    }

    public var body: some View {
        HStack(spacing: Spacing.xxl) {
            ForEach(tabs) { tab in
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { selection = tab.value }
                } label: {
                    Text(tab.title)
                        .textCase(.uppercase)
                        .font(AppFont.headline)
                        .foregroundStyle(tab.value == selection ? Color.ds.brandAccent : Color.ds.textPrimary
                            .opacity(0.5))
                }
                .accessibilityAddTraits(tab.value == selection ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview("Text tabs") {
    @Previewable @State var selection = 0
    TextTabs(selection: $selection, tabs: [TextTab(0, "Phone Number"), TextTab(1, "Email")])
}
