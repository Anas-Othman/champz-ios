import SwiftUI

/// Every icon the app uses, by role. SF Symbols by default; a case can switch to a
/// bundled asset without touching call sites. No `Image("...")` literals in features.
public enum AppIcon: String, CaseIterable, Sendable {
    case home = "house.fill"
    case transferMarket = "arrow.left.arrow.right"
    case stats = "chart.bar.fill"
    case notifications = "bell.fill"
    case settings = "gearshape.fill"
    case wallet = "creditcard.fill"
    case applePay = "apple.logo"
    case cash = "banknote"
    case calendar
    case clock
    case location = "mappin.and.ellipse"
    case players = "person.2.fill"
    case team = "person.3.fill"
    case trophy = "trophy.fill"
    case football = "soccerball"
    case chat = "bubble.left.and.bubble.right.fill"
    case share = "square.and.arrow.up"
    case filter = "line.3.horizontal.decrease.circle"
    case search = "magnifyingglass"
    case chevronRight = "chevron.right"
    case chevronDown = "chevron.down"
    case close = "xmark"
    case back = "chevron.backward"
    case check = "checkmark"
    case checkCircle = "checkmark.circle.fill"
    case warning = "exclamationmark.triangle.fill"
    case error = "xmark.octagon.fill"
    case info = "info.circle.fill"
    case offline = "wifi.slash"
    case empty = "tray"
    case edit = "pencil"
    case camera = "camera.fill"
    case plus

    public var image: Image {
        Image(systemName: rawValue)
    }

    /// Arrows and chevrons flip in right-to-left layouts.
    var flipsInRTL: Bool {
        switch self {
        case .chevronRight, .back, .transferMarket: true
        default: false
        }
    }
}

public extension Image {
    init(_ icon: AppIcon) {
        self.init(systemName: icon.rawValue)
    }
}
