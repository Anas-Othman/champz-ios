import SwiftUI

/// Every button in the app. Variants are styles, not copies; loading and disabled
/// states are built in. Usage: `AppButton(L10n.Match.join, style: .primary) { ... }`.
public struct AppButton: View {
    public enum Style: Sendable {
        case primary
        case secondary
        case destructive
        /// White with a red label and hairline border (Leave match).
        case destructiveOutline
        case text
    }

    private let title: LocalizedStringResource
    private let style: Style
    private let icon: AppIcon?
    private let isLoading: Bool
    private let action: () -> Void

    public init(
        _ title: LocalizedStringResource,
        style: Style = .primary,
        icon: AppIcon? = nil,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.icon = icon
        self.isLoading = isLoading
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.s) {
                if let icon {
                    Image(icon)
                }
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .opacity(isLoading ? 0 : 1)
            .overlay {
                if isLoading {
                    ProgressView().tint(foreground)
                }
            }
        }
        .buttonStyle(AppButtonStyle(style: style))
        .disabled(isLoading)
        .accessibilityLabel(Text(title))
    }

    private var foreground: Color {
        switch style {
        case .primary, .destructive: .ds.onBrand
        case .secondary, .text: .ds.brandPrimary
        case .destructiveOutline: .ds.destructiveText
        }
    }
}

struct AppButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    let style: AppButton.Style

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.button)
            .foregroundStyle(foreground)
            .frame(maxWidth: style == .text ? nil : .infinity)
            .frame(minHeight: style == .text ? ControlSize.minimumTapTarget : ControlSize.button)
            .padding(.horizontal, style == .text ? Spacing.s : Spacing.l)
            .background(background, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
            .overlay {
                if style == .secondary || style == .destructiveOutline {
                    RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                        .strokeBorder(
                            style == .secondary ? Color.ds.brandPrimary : Color.ds.hairline,
                            lineWidth: style == .secondary ? 1 : 1.5
                        )
                }
            }
            .opacity(isEnabled ? 1 : 0.5)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private var foreground: Color {
        switch style {
        case .primary, .destructive: .ds.onBrand
        case .secondary, .text: .ds.brandPrimary
        case .destructiveOutline: .ds.destructiveText
        }
    }

    private var background: Color {
        switch style {
        case .primary: .ds.brandPrimary
        case .destructive: .ds.statusError
        case .secondary, .destructiveOutline: .ds.surface
        case .text: .clear
        }
    }
}

#Preview("Buttons") {
    VStack(spacing: Spacing.l) {
        AppButton("Primary", style: .primary) {}
        AppButton("Loading", style: .primary, isLoading: true) {}
        AppButton("Secondary", style: .secondary, icon: .wallet) {}
        AppButton("Destructive", style: .destructive) {}
        AppButton("Text button", style: .text) {}
        AppButton("Disabled", style: .primary) {}.disabled(true)
    }
    .padding(Spacing.gutter)
}
