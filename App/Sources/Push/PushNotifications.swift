import ChampzKit
@preconcurrency import FirebaseMessaging
import UIKit
import UserNotifications

/// UIKit's one hook SwiftUI has no equivalent for: the APNs device token. Firebase needs it
/// to issue the FCM token (swizzling is off, see `FirebaseAppDelegateProxyEnabled`).
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        guard FirebaseSetup.isConfigured else { return }
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(_: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: any Error) {
        Log.app.notice("APNs registration failed: \(error.localizedDescription, privacy: .public)")
    }
}

/// Push notifications end to end:
/// - after sign-in: ask permission (once; iOS remembers), register with APNs, send the FCM token to `POST /devices/`;
/// - a token rotation re-registers; sign-out deletes the token so the old account stops getting pushes;
/// - in the foreground: show the banner and refresh the bells;
/// - a tap: mark it read and open what it is about — after sign-in if the app was launched by the tap.
@MainActor
final class PushNotifications: NSObject {
    private let notifications: any NotificationRepository
    private let router: AppRouter
    private let changes: DataChanges
    private let isSignedIn: @MainActor () -> Bool

    init(
        notifications: any NotificationRepository,
        router: AppRouter,
        changes: DataChanges,
        isSignedIn: @escaping @MainActor () -> Bool
    ) {
        self.notifications = notifications
        self.router = router
        self.changes = changes
        self.isSignedIn = isSignedIn
    }

    /// Once at launch, before any notification can be delivered or tapped.
    func install() {
        UNUserNotificationCenter.current().delegate = self
        if FirebaseSetup.isConfigured {
            Messaging.messaging().delegate = self
        }
    }

    /// After sign-in (or a restored session).
    func start() async {
        guard FirebaseSetup.isConfigured else { return }
        let center = UNUserNotificationCenter.current()
        let granted = await (try? center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
        guard granted else {
            Log.app.info("Push permission not granted")
            return
        }
        UIApplication.shared.registerForRemoteNotifications()
        if let token = try? await (Messaging.messaging() as any FCMTokens).currentToken() {
            await register(token)
        }
    }

    /// On sign-out: this phone stops receiving the old account's pushes.
    func stop() async {
        guard FirebaseSetup.isConfigured else { return }
        try? await (Messaging.messaging() as any FCMTokens).removeToken()
        try? await UNUserNotificationCenter.current().setBadgeCount(0)
    }

    fileprivate func register(_ token: String) async {
        guard isSignedIn() else { return } // sent again by `start()` after sign-in
        do {
            try await notifications.registerDevice(token: token)
            Log.app.info("Push token registered")
        } catch {
            Log.app.notice("Push token registration failed: \(String(describing: error), privacy: .public)")
        }
    }

    fileprivate func open(_ payload: PushPayload) {
        if let id = payload.notificationID {
            Task {
                try? await notifications.markRead(id)
                changes.notificationsChanged()
            }
        }
        if let route = payload.route {
            router.open(.push(route), isSignedIn: isSignedIn())
        }
    }
}

extension PushNotifications: UNUserNotificationCenterDelegate {
    /// In the foreground: still show it, and let the bells catch up.
    nonisolated func userNotificationCenter(
        _: UNUserNotificationCenter,
        willPresent _: UNNotification
    ) async -> UNNotificationPresentationOptions {
        await MainActor.run { changes.notificationsChanged() }
        return [.banner, .list, .sound, .badge]
    }

    nonisolated func userNotificationCenter(
        _: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let payload = PushPayload(response.notification.request.content.userInfo)
        await MainActor.run { open(payload) }
    }
}

extension PushNotifications: MessagingDelegate {
    /// Firebase issued or rotated the token.
    nonisolated func messaging(_: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        Task { @MainActor in await register(fcmToken) }
    }
}

/// The FCM *token* calls. Firebase 12 deprecates them in favour of an opt-in model that addresses
/// devices by Firebase Installation ID, but our backend (and the Android app) push to FCM tokens,
/// so tokens are what we must register. The deprecation is contained here: the witnesses are
/// marked deprecated themselves, and callers go through this protocol.
/// Revisit when the backend sends by installation ID.
private protocol FCMTokens {
    func currentToken() async throws -> String
    func removeToken() async throws
}

extension Messaging: FCMTokens {
    @available(*, deprecated, message: "FCM token API — see FCMTokens")
    func currentToken() async throws -> String {
        try await token()
    }

    @available(*, deprecated, message: "FCM token API — see FCMTokens")
    func removeToken() async throws {
        try await deleteToken()
    }
}
