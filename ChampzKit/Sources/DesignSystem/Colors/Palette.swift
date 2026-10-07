import SwiftUI

/// THE ONLY FILE IN THE APP WITH COLOR VALUES (lint rule `no_raw_colors`).
/// Values come from the Flutter app's `theme_helper.dart`, named by hue and step.
/// Features never use these directly; they use the semantic tokens in `ColorTokens`.
enum Palette {
    // Brand
    static let indigo900 = Color(hex: 0x021067) // Flutter indigo900 / blueColor — primary brand
    static let purple600 = Color(hex: 0x9B10C1) // purple
    static let purple500 = Color(hex: 0x9046EA) // newPurple
    static let purple100 = Color(hex: 0xEADDFB) // purple50 / lightpink
    static let purple200 = Color(hex: 0xCCAAF5) // newPurple200
    static let purple300 = Color(hex: 0xC89AFF) // lightPurple2
    static let purple400 = Color(hex: 0xAB67FF) // pink1
    static let purple800 = Color(hex: 0x4D2183) // darkPurple
    static let pink500 = Color(hex: 0xC03DE0) // newpink / pink
    static let pink700 = Color(hex: 0x9224AC) // newpink1

    // Neutrals
    static let black = Color(hex: 0x000000) // black900
    static let gray900 = Color(hex: 0x323232) // black350 / gray900
    static let gray700 = Color(hex: 0x646464) // black250 / grayBorder
    static let gray650 = Color(hex: 0x686868) // textColor / gray700
    static let gray600 = Color(hex: 0x6A6A6D) // textSecondary
    static let gray500 = Color(hex: 0x969696) // greyTextColor
    static let gray400 = Color(hex: 0xA0A0A0) // unselectedRadioColor
    static let gray300 = Color(hex: 0xC8C8C8) // black50
    static let gray250 = Color(hex: 0xCFCFCF) // containerBorderColor
    static let gray200 = Color(hex: 0xE0E0E0) // gray300 / shapeborderColor
    static let gray150 = Color(hex: 0xE3E3E3) // borderColor
    static let gray100 = Color(hex: 0xEFEFEF) // separatorColor
    static let gray75 = Color(hex: 0xF5F5F5) // filterColor
    static let gray50 = Color(hex: 0xF7F7F7) // backgroundColor
    static let gray25 = Color(hex: 0xF8F8F8) // greyButtonColor
    static let white = Color(hex: 0xFFFFFF)

    // Status
    static let green500 = Color(hex: 0x1EBA7C) // green
    static let green600 = Color(hex: 0x43A047) // green600
    static let red500 = Color(hex: 0xEE5356) // redAlert
    static let red600 = Color(hex: 0xCA3A3A) // red
    static let red400 = Color(hex: 0xFF383C) // leave-match text
    static let hairline = Color(hex: 0x323232, opacity: 0.08) // outline buttons
    static let shadow = Color(hex: 0x000000, opacity: 0.06) // card shadow
    static let amber500 = Color(hex: 0xF59E0B) // yellow
    static let orange500 = Color(hex: 0xFAB600) // orange
    static let blue500 = Color(hex: 0x222FBD) // blue
    static let blue100 = Color(hex: 0xDDEDFF) // lightBlueColor
}

extension Color {
    /// `Color(hex: 0x021067)`. Allowed here only.
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
