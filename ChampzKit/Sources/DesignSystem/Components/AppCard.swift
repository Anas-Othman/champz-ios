import SwiftUI

/// The standard container surface: white, rounded, hairline border.
public struct AppCard<Content: View>: View {
    private let padding: CGFloat
    private let content: Content

    public init(padding: CGFloat = Spacing.l, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.ds.surface, in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.l, style: .continuous)
                    .strokeBorder(Color.ds.border, lineWidth: 1)
            }
    }
}

/// A heading row above a list or card group, with an optional trailing action.
public struct SectionHeader: View {
    private let title: LocalizedStringResource
    private let actionTitle: LocalizedStringResource?
    private let action: (() -> Void)?

    public init(
        _ title: LocalizedStringResource,
        actionTitle: LocalizedStringResource? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(AppFont.sectionHeader)
                .textCase(.uppercase) // all section titles in capitals, whatever the string's own case
                .foregroundStyle(.ds.textPrimary)
            Spacer()
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(AppFont.bodyEmphasis)
                        .foregroundStyle(.ds.brandPrimary)
                }
            }
        }
    }
}

#Preview("Card") {
    VStack(spacing: Spacing.l) {
        SectionHeader("Upcoming matches", actionTitle: "See all") {}
        AppCard {
            Text(verbatim: "Card content").font(AppFont.body)
        }
    }
    .padding(Spacing.gutter)
    .background(Color.ds.backgroundMuted)
}
