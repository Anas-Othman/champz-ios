import Foundation

/// `GET /api/v1/notifications/preferences/` — one toggle on the notification settings screen.
public struct NotificationPreference: Decodable, Hashable, Sendable, Identifiable {
    public let key: String
    @DefaultEmpty public var title: String
    @DefaultFalse public var isEnabled: Bool

    public var id: String {
        key
    }
}

/// The legal and info pages the CMS serves (`GET /api/v1/cms/pages/{type}/`).
public enum CmsPageType: String, Hashable, Sendable {
    case privacyPolicy = "privacy_policy"
    case termsOfService = "terms_of_service"
}

public struct CmsPage: Decodable, Hashable, Sendable {
    @DefaultEmpty public var name: String
    /// HTML.
    @DefaultEmpty public var description: String
}

/// `GET /api/v1/cms/faqs/`.
public struct Faq: Decodable, Hashable, Sendable, Identifiable {
    public let id: String
    @DefaultEmpty public var title: String
    @DefaultEmpty public var description: String
}

/// `GET /api/v1/profile/deletion/` — what deleting my account would do right now (nothing is changed).
public struct DeletionState: Decodable, Hashable, Sendable {
    @DefaultFalse public var canDelete: Bool
    @LossyArray public var blockers: [DeletionBlocker]
    @StrictDecimal public var walletBalance: Decimal
    @DefaultEmpty public var currency: String
    /// Signing in on this phone within this many days restores the account (and a kept balance).
    @DefaultZero public var reactivationWindowDays: Int

    public var balance: Money {
        Money(walletBalance, currency: currency.isEmpty ? Money.defaultCurrency : currency)
    }
}

/// Something to clear before the account can go: a club I captain, or an upcoming booking or game.
public struct DeletionBlocker: Decodable, Hashable, Sendable {
    /// "club", or the kind of fixture.
    @DefaultEmpty public var kind: String
    /// The club's, venue's or game's name.
    @DefaultEmpty public var label: String
    /// "yyyy-MM-dd", empty for a club.
    @DefaultEmpty public var on: String

    public var isClub: Bool {
        kind == "club"
    }
}

/// What happens to my wallet balance when I delete my account. (Transfer to a player comes with wallet transfers.)
public enum BalanceDisposition: String, Hashable, Sendable, CaseIterable {
    /// Restored if I sign in again within the window; after it, it goes to Champz.
    case keep
    case giveToChampz = "give_to_champz"
}
