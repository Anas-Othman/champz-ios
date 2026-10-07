import Foundation

/// `GET /api/v1/notifications/` — one item in my feed (last 30 days, newest first).
public struct AppNotification: Decodable, Hashable, Sendable, Identifiable {
    /// What the notification is about (backend `NotifyType`).
    public enum Kind: Int, Sendable, UnknownCaseRepresentable {
        case match = 0, transferTournament = 1, transferFriendly = 2, courtBooking = 4, friendlyJoin = 5
        case unknown = -1
    }

    /// Backend `NotificationStatus`.
    public enum Status: Int, Sendable, UnknownCaseRepresentable {
        case actionable = 0, accepted = 1, declined = 2, informational = 3
        case unknown = -1
    }

    public let id: NotificationID
    @DefaultEmpty public var title: String
    @DefaultEmpty public var message: String
    @DefaultUnknown public var notifyType: Kind
    @DefaultUnknown public var status: Status
    @DefaultFalse public var isRead: Bool
    @DefaultFalse public var isFromInvitation: Bool
    @DefaultEmpty public var tournamentId: String
    @DefaultEmpty public var bookingId: String
    @DefaultEmpty public var matchId: String
    /// Who triggered it (the sender of a transfer offer…).
    @DefaultEmpty public var actorId: String
    @DefaultEmpty public var createdAt: String

    public var date: Date? {
        Date.parseAPI(createdAt)
    }

    /// An invite to share a court booking that still waits for an answer.
    public var isOpenBookingInvite: Bool {
        notifyType == .courtBooking && status == .actionable && !bookingId.isEmpty
    }

    /// Where tapping it goes. The same rule opens a tapped push banner.
    public var target: AppRoute? {
        NotificationTarget.route(
            kind: notifyType,
            tournamentID: tournamentId,
            bookingID: bookingId,
            matchID: matchId,
            playerID: actorId
        )
    }
}

/// Where a notification leads, for feed rows and push banners alike
/// (notification_router.dart, with its broken branches fixed).
public enum NotificationTarget {
    public static func route(
        kind: AppNotification.Kind,
        tournamentID: String,
        bookingID: String,
        matchID: String,
        playerID: String
    ) -> AppRoute? {
        switch kind {
        case .courtBooking:
            bookingID.isEmpty ? nil : .bookingInvite(BookingID(bookingID))
        case .transferTournament, .transferFriendly:
            // Offers are shown, not answered, here yet: open the sender's profile.
            playerID.isEmpty ? nil : .playerProfile(PlayerID(playerID))
        case .match, .friendlyJoin, .unknown:
            if !tournamentID.isEmpty {
                .tournamentDetail(TournamentID(tournamentID))
            } else if !matchID.isEmpty {
                .matchDetail(MatchID(matchID))
            } else {
                nil
            }
        }
    }
}

/// The data part of a push (FCM sends every value as a string): `notify_type`,
/// `notification_id` and the reference ids of what it is about.
public struct PushPayload: Hashable, Sendable {
    public let notificationID: NotificationID?
    public let route: AppRoute?

    public init(_ data: [AnyHashable: Any]) {
        func value(_ key: String) -> String {
            switch data[key] {
            case let text as String: text
            case let number as NSNumber: number.stringValue
            default: ""
            }
        }
        let id = value("notification_id")
        notificationID = id.isEmpty ? nil : NotificationID(id)
        let kind = Int(value("notify_type")).flatMap(AppNotification.Kind.init(rawValue:)) ?? .unknown
        // The sender of an offer arrives as `actor_id` (or `player_id` / `user_id` from older payloads).
        let player = [value("actor_id"), value("player_id"), value("user_id")].first { !$0.isEmpty } ?? ""
        let route = NotificationTarget.route(
            kind: kind,
            tournamentID: value("tournament_id"),
            bookingID: value("booking_id"),
            matchID: value("match_id"),
            playerID: player
        )
        // Nothing specific to open: the notifications list, where it is.
        self.route = route ?? .notifications
    }
}

public struct UnreadCount: Decodable, Sendable {
    @DefaultZero public var unreadCount: Int
}
