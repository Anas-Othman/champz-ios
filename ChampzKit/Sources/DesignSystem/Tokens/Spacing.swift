import SwiftUI

/// The spacing scale. Paddings and stack spacing come from here, never from literals.
public enum Spacing {
    public static let xxs: CGFloat = 2
    public static let xs: CGFloat = 4
    public static let s: CGFloat = 8
    public static let m: CGFloat = 12
    public static let l: CGFloat = 16
    public static let xl: CGFloat = 24
    public static let xxl: CGFloat = 32
    public static let xxxl: CGFloat = 48

    /// Horizontal screen gutter.
    public static let gutter: CGFloat = 16
}

/// Corner radii.
public enum Radius {
    public static let s: CGFloat = 8
    public static let m: CGFloat = 12
    public static let l: CGFloat = 16
    public static let xl: CGFloat = 24
    public static let pill: CGFloat = 999
}

/// Standard control heights.
public enum ControlSize {
    public static let button: CGFloat = 52
    public static let field: CGFloat = 52
    public static let minimumTapTarget: CGFloat = 44
}
