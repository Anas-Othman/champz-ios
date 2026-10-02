import SwiftUI

/// Six code boxes backed by one invisible text field. One field (not six) means the
/// keyboard stays up, paste works, and iOS's SMS one-time-code autofill fills it in.
public struct OTPCodeField: View {
    @Binding private var code: String
    private let length: Int
    private let onComplete: ((String) -> Void)?

    @FocusState private var isFocused: Bool

    public init(code: Binding<String>, length: Int = 6, onComplete: ((String) -> Void)? = nil) {
        _code = code
        self.length = length
        self.onComplete = onComplete
    }

    public var body: some View {
        ZStack {
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($isFocused)
                .frame(width: 1, height: 1)
                .opacity(0.01)
                .accessibilityHidden(true)

            HStack(spacing: Spacing.s) {
                ForEach(0 ..< length, id: \.self) { index in
                    box(at: index)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { isFocused = true }
        .onAppear { isFocused = true }
        .onChange(of: code) { _, newValue in
            let digits = String(newValue.filter(\.isNumber).prefix(length))
            if digits != newValue {
                code = digits
            }
            if digits.count == length {
                onComplete?(digits)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityValue(Text(verbatim: code))
    }

    private func box(at index: Int) -> some View {
        let digits = Array(code)
        let character = index < digits.count ? String(digits[index]) : ""
        let isActive = isFocused && index == min(digits.count, length - 1)
        return Text(verbatim: character)
            .font(AppFont.title2)
            .foregroundStyle(.ds.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.ds.surface, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                    .strokeBorder(isActive ? Color.ds.brandPrimary : Color.ds.border, lineWidth: isActive ? 1.5 : 1)
            }
    }
}

#Preview("OTP") {
    @Previewable @State var code = "12"
    OTPCodeField(code: $code).padding(Spacing.gutter)
}
