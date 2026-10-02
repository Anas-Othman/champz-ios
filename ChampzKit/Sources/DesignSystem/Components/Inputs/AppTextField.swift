import SwiftUI

/// The standard text input: optional label above, bordered field, optional error below.
/// Every text entry in the app is one of these, so focus, border and error styling stay uniform.
public struct AppTextField: View {
    private let label: LocalizedStringResource?
    private let placeholder: LocalizedStringResource
    @Binding private var text: String
    private let error: String?
    private let keyboard: UIKeyboardType
    private let contentType: UITextContentType?
    private let autocapitalization: TextInputAutocapitalization
    private let leading: AnyView?

    @FocusState private var isFocused: Bool

    public init(
        _ placeholder: LocalizedStringResource,
        text: Binding<String>,
        label: LocalizedStringResource? = nil,
        error: String? = nil,
        keyboard: UIKeyboardType = .default,
        contentType: UITextContentType? = nil,
        autocapitalization: TextInputAutocapitalization = .sentences,
        @ViewBuilder leading: () -> some View = { EmptyView() }
    ) {
        self.placeholder = placeholder
        _text = text
        self.label = label
        self.error = error
        self.keyboard = keyboard
        self.contentType = contentType
        self.autocapitalization = autocapitalization
        let leadingView = leading()
        self.leading = leadingView is EmptyView ? nil : AnyView(leadingView)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            if let label {
                Text(label)
                    .font(AppFont.caption)
                    .foregroundStyle(.ds.textSecondary)
            }
            HStack(spacing: Spacing.s) {
                if let leading {
                    leading
                    Rectangle()
                        .fill(Color.ds.border)
                        .frame(width: 1, height: 24)
                }
                TextField(text: $text) {
                    Text(placeholder).foregroundStyle(.ds.textTertiary)
                }
                .font(AppFont.bodyLarge)
                .foregroundStyle(.ds.textPrimary)
                .keyboardType(keyboard)
                .textContentType(contentType)
                .textInputAutocapitalization(autocapitalization)
                .autocorrectionDisabled(keyboard != .default)
                .focused($isFocused)
            }
            .padding(.horizontal, Spacing.l)
            .frame(minHeight: ControlSize.field)
            .background(Color.ds.surface, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: isFocused ? 1.5 : 1)
            }
            .contentShape(Rectangle())
            .onTapGesture { isFocused = true }
            if let error {
                Text(error)
                    .font(AppFont.caption)
                    .foregroundStyle(.ds.statusError)
            }
        }
        .animation(.easeOut(duration: 0.15), value: isFocused)
    }

    private var borderColor: Color {
        if error != nil {
            return .ds.statusError
        }
        return isFocused ? .ds.brandPrimary : .ds.border
    }
}

#Preview("Text fields") {
    @Previewable @State var text = ""
    VStack(spacing: Spacing.l) {
        AppTextField("Enter Email", text: $text, label: "Email", keyboard: .emailAddress)
        AppTextField("Enter your phone number", text: $text, error: "Please enter a valid number", keyboard: .phonePad)
    }
    .padding(Spacing.gutter)
}
