import SwiftUI

/// Semantic colors, named by role, never by hue. `Color.ds.textPrimary`.
/// A rebrand or dark mode changes `Palette` or this mapping; features stay untouched.
/// v1 is light-only for parity with the current app (`.preferredColorScheme(.light)` at the root).
public struct ColorTokens: Sendable {
    // Brand
    public let brandPrimary = Palette.purple500
    public let brandAccent = Palette.purple500
    /// The deep navy used for headings and some surfaces in the current app.
    public let brandNavy = Palette.indigo900
    public let brandAccentSoft = Palette.purple100
    public let onBrand = Palette.white

    // Text
    public let textPrimary = Palette.black
    public let textSecondary = Palette.gray700
    public let textTertiary = Palette.gray500
    public let textDisabled = Palette.gray300
    public let textOnDark = Palette.white

    // Surfaces
    public let background = Palette.white
    public let backgroundMuted = Palette.gray50
    public let surface = Palette.white
    public let surfaceRaised = Palette.gray25
    public let surfaceMuted = Palette.gray75
    public let skeleton = Palette.gray100

    // Lines
    public let border = Palette.gray150
    public let borderStrong = Palette.gray250
    public let separator = Palette.gray100

    // Status
    public let statusSuccess = Palette.green500
    public let statusError = Palette.red500
    public let statusWarning = Palette.amber500
    public let statusInfo = Palette.blue500
    public let statusInfoSoft = Palette.blue100

    // Controls
    public let controlUnselected = Palette.gray400
    public let buttonSecondaryBackground = Palette.gray25
}

public extension Color {
    static let ds = ColorTokens()
}

public extension ShapeStyle where Self == Color {
    /// `.foregroundStyle(.ds.textSecondary)`
    static var ds: ColorTokens {
        ColorTokens()
    }
}
