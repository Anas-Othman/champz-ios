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
    case arrowRight = "arrow.right"
    case arrowUp = "arrow.up"
    case arrowDown = "arrow.down"
    case send = "paperplane.fill"
    case lock = "lock.fill"
    case document = "doc.text.fill"
    case logOut = "rectangle.portrait.and.arrow.right"
    case delete = "trash"
    case email = "envelope.fill"
    case more = "ellipsis.circle"
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
    case circle
    case square
    case checkSquare = "checkmark.square.fill"
    case phone = "phone.fill"
    // Bundled artwork (DesignSystem/Resources/Icons.xcassets), rendered as templates.
    case matchCompetitive = "match-competitive"
    case matchFriendly = "match-friendly"
    case brandClock = "icon-clock"
    case brandMapPin = "icon-map-pin"
    case brandShare = "icon-share"
    case brandChat = "icon-chat"
    case brandPlayers = "icon-players"
    case whatsApp = "icon-whatsapp"
    case verified = "icon-verified"
    case tournamentTrophy = "icon-trophy-tournament"
    case playersFilled = "icon-players-filled"
    case person = "icon-person"
    case medal = "icon-medal"
    /// Background art for the tournament info card.
    case champzLetters = "art-champz-letters"

    private var isAsset: Bool {
        switch self {
        case .matchCompetitive, .matchFriendly, .brandClock, .brandMapPin, .brandShare, .brandChat, .brandPlayers,
             .whatsApp, .verified, .tournamentTrophy, .playersFilled, .person, .medal, .champzLetters: true
        default: false
        }
    }

    public var image: Image {
        isAsset ? Image(rawValue, bundle: .module) : Image(systemName: rawValue)
    }

    /// Arrows and chevrons flip in right-to-left layouts.
    var flipsInRTL: Bool {
        switch self {
        case .chevronRight, .back, .transferMarket, .arrowRight: true
        default: false
        }
    }
}

public extension Image {
    init(_ icon: AppIcon) {
        self = icon.image
    }
}
