import SwiftUI

/// Every text style in the app. ClashDisplay for display and titles, Satoshi for body,
/// matching the Flutter app. All styles scale with Dynamic Type via `relativeTo:`.
/// Falls back to the system font if a custom font failed to register, so a missing
/// font file degrades the look, never the app.
public enum AppFont {
    enum Family {
        static let display = "ClashDisplay"
        /// The variable Satoshi file; weights come from the file's named instances.
        static let body = "SatoshiVariable-Bold"
        /// Graphik Arabic — Flutter's `AppConstant.graphicArabic`, used for detail labels and body text.
        static let graphik = "GraphikArabic"
    }

    /// 36pt display, bold.
    public static let display = custom(Family.display, weight: .bold, size: 36, relativeTo: .largeTitle)
    /// 28pt.
    public static let title1 = custom(Family.display, weight: .semibold, size: 28, relativeTo: .title)
    /// 20pt.
    public static let title2 = custom(Family.display, weight: .semibold, size: 20, relativeTo: .title2)
    /// 20pt bold Clash — section titles on Home ("Upcoming Matches", "Book a Court"…).
    public static let sectionHeader = custom(Family.display, weight: .bold, size: 20, relativeTo: .title3)
    /// 18pt — the Flutter app's section-heading size.
    public static let headline = custom(Family.display, weight: .medium, size: 18, relativeTo: .headline)
    /// 16pt.
    public static let bodyLarge = custom(Family.body, weight: .regular, size: 16, relativeTo: .body)
    /// 14pt — the Flutter app's default body size.
    public static let body = custom(Family.body, weight: .regular, size: 14, relativeTo: .callout)
    /// 14pt emphasised.
    public static let bodyEmphasis = custom(Family.body, weight: .medium, size: 14, relativeTo: .callout)
    /// 13pt.
    public static let caption = custom(Family.body, weight: .regular, size: 13, relativeTo: .footnote)
    /// 12pt.
    public static let captionSmall = custom(Family.body, weight: .regular, size: 12, relativeTo: .caption)
    /// 24pt bold Clash — titles on detail screens.
    public static let screenTitle = custom(Family.display, weight: .bold, size: 24, relativeTo: .title)
    /// 18pt medium Graphik — date/venue lines under a title.
    public static let detailLine = custom(Family.graphik, weight: .medium, size: 18, relativeTo: .headline)
    /// 18pt bold Graphik — section headings (Description, Location…).
    public static let sectionTitle = custom(Family.graphik, weight: .bold, size: 18, relativeTo: .headline)
    /// 16pt medium Graphik — labels in info cards.
    public static let infoLabel = custom(Family.graphik, weight: .medium, size: 16, relativeTo: .body)
    /// 16pt bold Clash — values in info cards and names.
    public static let infoValue = custom(Family.display, weight: .bold, size: 16, relativeTo: .body)
    /// 14pt medium Graphik — body copy on detail screens.
    public static let detailBody = custom(Family.graphik, weight: .medium, size: 14, relativeTo: .callout)
    /// 18pt bold Graphik — large action buttons and counters.
    public static let buttonLarge = custom(Family.graphik, weight: .bold, size: 18, relativeTo: .headline)
    /// Large state icons (empty/error screens).
    public static let stateIcon = Font.system(size: 40)
    /// Buttons: 16pt medium.
    public static let button = custom(Family.body, weight: .medium, size: 16, relativeTo: .body)

    private static func custom(
        _ family: String,
        weight: Font.Weight,
        size: CGFloat,
        relativeTo style: Font.TextStyle
    ) -> Font {
        let name = postScriptName(family: family, weight: weight)
        guard FontRegistrar.isAvailable(name) else {
            return .system(size: size, weight: weight)
        }
        return .custom(name, size: size, relativeTo: style)
    }

    private static func postScriptName(family: String, weight: Font.Weight) -> String {
        if family == Family.graphik {
            switch weight {
            case .bold, .heavy, .black, .semibold: return "GraphikArabic-Bold"
            case .medium: return "GraphikArabic-Medium"
            default: return "GraphikArabic-Regular"
            }
        }
        guard family == Family.display else { return family }
        switch weight {
        case .bold, .heavy, .black: return "ClashDisplay-Bold"
        case .semibold: return "ClashDisplay-Semibold"
        case .medium: return "ClashDisplay-Medium"
        default: return "ClashDisplay-Regular"
        }
    }
}
