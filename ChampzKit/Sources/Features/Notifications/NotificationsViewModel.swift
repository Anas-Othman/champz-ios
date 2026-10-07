import Foundation
import Observation

/// "NOTIFICATIONS" (notification_screen.dart): my feed, newest first, paged; tap to open,
/// mark all as read, and answer court-booking invites.
@MainActor
@Observable
public final class NotificationsViewModel {
    public private(set) var state: Loadable<[AppNotification]> = .idle
    public private(set) var isLoadingMore = false
    /// The invite waiting for "Decline?" to be confirmed.
    public var inviteToDecline: AppNotification?
    /// Invites answered on this screen: their buttons go away at once, before the feed catches up.
    public private(set) var answered: Set<NotificationID> = []

    private var nextCursor = ""
    private let notifications: any NotificationRepository
    private let courts: any CourtRepository
    private let router: AppRouter
    private let toasts: ToastCenter
    private let changes: DataChanges?

    public init(
        notifications: any NotificationRepository,
        courts: any CourtRepository,
        router: AppRouter,
        toasts: ToastCenter,
        changes: DataChanges? = nil
    ) {
        self.notifications = notifications
        self.courts = courts
        self.router = router
        self.toasts = toasts
        self.changes = changes
    }

    public var hasUnread: Bool {
        state.value?.contains { !$0.isRead } ?? false
    }

    public func load() async {
        guard case .idle = state else { return }
        state = .loading
        await reload()
    }

    public func reload() async {
        do {
            let page = try await notifications.notifications(cursor: nil)
            nextCursor = page.nextCursor
            state = .loaded(page.items)
        } catch {
            if case .loaded = state {
                toasts.show(error)
            } else {
                state = .failed(error)
            }
        }
    }

    /// Call from each row as it appears; only the last one loads the next page.
    /// (The current app only ever showed the first page.)
    public func loadMoreIfNeeded(after item: AppNotification) async {
        guard !nextCursor.isEmpty, !isLoadingMore, case let .loaded(items) = state,
              items.last?.id == item.id else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await notifications.notifications(cursor: nextCursor)
            nextCursor = page.nextCursor
            state = .loaded(items + page.items)
        } catch {
            toasts.show(error)
        }
    }

    public func showsInviteButtons(_ item: AppNotification) -> Bool {
        item.isOpenBookingInvite && !answered.contains(item.id)
    }

    /// Opens what it is about, and marks it read.
    public func open(_ item: AppNotification) {
        markRead(item)
        if let target = item.target {
            router.push(target)
        }
    }

    public func markAllRead() async {
        guard case var .loaded(items) = state, hasUnread else { return }
        let before = items
        for index in items.indices {
            items[index].isRead = true
        }
        state = .loaded(items)
        do {
            try await notifications.markRead(nil)
            changes?.notificationsChanged()
        } catch {
            state = .loaded(before) // the dots come back: the server did not take it
            toasts.show(error)
        }
    }

    /// Asks first; the share stays owed by the host, so it is worth a second thought.
    public func askToDecline(_ item: AppNotification) {
        inviteToDecline = item
    }

    public func confirmDecline() async {
        guard let item = inviteToDecline else { return }
        inviteToDecline = nil
        do {
            _ = try await courts.declineInvite(BookingID(item.bookingId))
            answered.insert(item.id)
            markRead(item)
            toasts.show(Toast(.info, L10n.Notifications.inviteDeclined))
        } catch {
            toasts.show(error)
        }
    }

    // MARK: - Helpers

    /// Optimistic: the dot goes at once; the server is told in the background.
    private func markRead(_ item: AppNotification) {
        guard !item.isRead, case var .loaded(items) = state,
              let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isRead = true
        state = .loaded(items)
        Task {
            try? await notifications.markRead(item.id)
            changes?.notificationsChanged()
        }
    }
}
