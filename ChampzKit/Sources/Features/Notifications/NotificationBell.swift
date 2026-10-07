import Observation
import SwiftUI

/// The unread count shown on every bell. One shared instance (the app puts it in the
/// environment); it asks the server whenever a bell appears or notifications change.
/// (The current app polled every 30 s and also changed the count on the phone, so it drifted.)
@MainActor
@Observable
public final class NotificationBadge {
    public private(set) var count = 0
    private let notifications: any NotificationRepository
    /// Mirrors the count on the app icon; the app passes it in (the package stays free of system notification APIs).
    private let showOnAppIcon: (@MainActor (Int) async -> Void)?

    public init(
        notifications: any NotificationRepository,
        showOnAppIcon: (@MainActor (Int) async -> Void)? = nil
    ) {
        self.notifications = notifications
        self.showOnAppIcon = showOnAppIcon
    }

    public func refresh() async {
        if let latest = try? await notifications.unreadCount() {
            count = latest
            await showOnAppIcon?(latest)
        }
    }
}

/// Bell button with a pink count. Refreshes itself; the screen only says where it goes.
public struct NotificationBell: View {
    @Environment(NotificationBadge.self) private var badge: NotificationBadge?
    @Environment(DataChanges.self) private var changes: DataChanges?
    let action: () -> Void

    public init(action: @escaping () -> Void) {
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(.notifications)
                .overlay(alignment: .topTrailing) {
                    if let count = badge?.count, count > 0 {
                        Text(verbatim: count > 99 ? "99+" : "\(count)")
                            .font(AppFont.captionSmall.weight(.bold))
                            .foregroundStyle(.ds.onBrand)
                            .padding(.horizontal, 4)
                            .frame(minWidth: 16, minHeight: 16)
                            .background(Color.ds.accent, in: Capsule())
                            .offset(x: 10, y: -8)
                    }
                }
        }
        .accessibilityLabel(Text(L10n.Notifications.notifications))
        .accessibilityValue(Text(verbatim: "\(badge?.count ?? 0)"))
        .task { await badge?.refresh() }
        .onChange(of: changes?.notificationsVersion) { Task { await badge?.refresh() } }
    }
}
