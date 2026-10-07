import Foundation

/// A parsed universal link, custom-scheme URL or push payload.
public enum DeepLink: Hashable, Sendable {
    case match(MatchID)
    case tournament(TournamentID)
    case booking(BookingID)
    case venue(VenueID)
    case team(TeamID)
    case wallet
    case notifications
    /// A tapped push notification: open what it is about.
    case push(AppRoute)
    /// `champz://payment/callback?status=paid|failed` — SkipCash's return after hosted checkout.
    case paymentCallback(PaymentCallbackStatus)
}

public enum PaymentCallbackStatus: String, Hashable, Sendable {
    case paid
    case failed
    case cancelled
}

/// Pure URL → `DeepLink`. Unit-tested against the link inventory; unknown links return nil.
///
/// Supported hosts: `champz.me`, `staging.champz.me`, and the `champz://` scheme.
/// IDs are opaque strings (ULIDs), taken as-is from the path.
/// TODO(open question): confirm the full path inventory against the Flutter `app_links` handler.
public enum DeepLinkParser {
    public static func parse(_ url: URL) -> DeepLink? {
        let segments = url.pathComponents.filter { $0 != "/" }
        // champz://payment/callback?status=paid → host "payment", path ["callback"]
        if url.scheme == "champz" {
            return parse(host: url.host ?? "", segments: segments, query: url.queryItems)
        }
        guard let host = url.host, host == "champz.me" || host == "staging.champz.me" || host == "www.champz.me" else {
            return nil
        }
        guard let first = segments.first else {
            return nil
        }
        return parse(host: first, segments: Array(segments.dropFirst()), query: url.queryItems)
    }

    /// Push notification payloads carry `type` and `id`.
    public static func parse(notification userInfo: [String: String]) -> DeepLink? {
        guard let type = userInfo["type"] else {
            return nil
        }
        let id = userInfo["id"].flatMap { $0.isEmpty ? nil : $0 }
        switch (type, id) {
        case let ("match", id?), let ("friendly_game", id?): return .match(MatchID(id))
        case let ("tournament", id?): return .tournament(TournamentID(id))
        case let ("booking", id?), let ("court_booking", id?): return .booking(BookingID(id))
        case let ("team", id?): return .team(TeamID(id))
        case ("wallet", _): return .wallet
        case ("notification", _), ("notifications", _): return .notifications
        default: return nil
        }
    }

    private static func parse(host: String, segments: [String], query: [String: String]) -> DeepLink? {
        let id = segments.first.flatMap { $0.isEmpty ? nil : $0 }
        switch (host, id) {
        case ("payment", _) where segments.first == "callback":
            return .paymentCallback(PaymentCallbackStatus(rawValue: query["status"] ?? "") ?? .failed)
        case let ("match", id?), let ("matches", id?), let ("games", id?): return .match(MatchID(id))
        case let ("tournament", id?), let ("tournaments", id?): return .tournament(TournamentID(id))
        case let ("booking", id?), let ("bookings", id?): return .booking(BookingID(id))
        case let ("venue", id?), let ("venues", id?): return .venue(VenueID(id))
        case let ("team", id?), let ("teams", id?): return .team(TeamID(id))
        case ("wallet", _): return .wallet
        case ("notifications", _): return .notifications
        default: return nil
        }
    }
}

private extension URL {
    var queryItems: [String: String] {
        URLComponents(url: self, resolvingAgainstBaseURL: false)?.queryItems?
            .reduce(into: [:]) { $0[$1.name] = $1.value ?? "" } ?? [:]
    }
}
