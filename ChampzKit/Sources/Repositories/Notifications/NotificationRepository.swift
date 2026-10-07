import Foundation

/// Endpoints under /api/v1/notifications/.
enum NotificationsAPI {
    static func list(cursor: String?) -> Endpoint<CursorPage<AppNotification>> {
        Endpoint(.get, "/api/v1/notifications/").query(["limit": "20", "cursor": cursor])
    }

    /// One notification, or all of mine when `id` is nil.
    static func markRead(_ id: NotificationID?) -> Endpoint<NoContent> {
        Endpoint(.post, "/api/v1/notifications/mark-read/").json(["notification_id": id?.raw])
    }

    /// This phone's FCM token, so the server can push to it. A token seen on another account moves to me.
    static func registerDevice(token: String) -> Endpoint<NoContent> {
        Endpoint(.post, "/api/v1/devices/").json(["token": token, "platform": "ios"])
    }

    static func unreadCount() -> Endpoint<UnreadCount> {
        Endpoint(.get, "/api/v1/notifications/unread-count/")
    }
}

public protocol NotificationRepository: Sendable {
    func notifications(cursor: String?) async throws(AppError) -> CursorPage<AppNotification>
    func markRead(_ id: NotificationID?) async throws(AppError)
    func unreadCount() async throws(AppError) -> Int
    func registerDevice(token: String) async throws(AppError)
}

public struct LiveNotificationRepository: NotificationRepository {
    let http: any HTTPClientProtocol

    public init(http: any HTTPClientProtocol) {
        self.http = http
    }

    public func notifications(cursor: String?) async throws(AppError) -> CursorPage<AppNotification> {
        try await http.send(NotificationsAPI.list(cursor: cursor))
    }

    public func markRead(_ id: NotificationID?) async throws(AppError) {
        _ = try await http.send(NotificationsAPI.markRead(id))
    }

    public func unreadCount() async throws(AppError) -> Int {
        try await http.send(NotificationsAPI.unreadCount()).unreadCount
    }

    public func registerDevice(token: String) async throws(AppError) {
        _ = try await http.send(NotificationsAPI.registerDevice(token: token))
    }
}
