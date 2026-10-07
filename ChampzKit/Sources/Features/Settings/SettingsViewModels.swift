import Foundation
import Observation

/// "More" (more_screen.dart): balance, account, support and legal rows, log out, delete account.
@MainActor
@Observable
public final class SettingsViewModel {
    public private(set) var balance: Money?
    public var isLogOutConfirmPresented = false
    public private(set) var isLoggingOut = false
    /// "Champz 2.0.0 (1)".
    public let versionText: String

    private let payments: any PaymentRepository
    private let router: AppRouter
    private let signOut: @MainActor () async -> Void

    /// - Parameter signOut: ends the session on this phone (the container also drops the push token).
    public init(
        payments: any PaymentRepository,
        router: AppRouter,
        versionText: String,
        signOut: @escaping @MainActor () async -> Void
    ) {
        self.payments = payments
        self.router = router
        self.versionText = versionText
        self.signOut = signOut
    }

    public func load() async {
        balance = try? await payments.wallet().money
    }

    public func open(_ route: AppRoute) {
        router.push(route)
    }

    public func editProfile() {
        router.present(.editProfile)
    }

    /// This phone only. (The current app called logout-all, signing the player out everywhere.)
    public func logOut() async {
        isLogOutConfirmPresented = false
        isLoggingOut = true
        defer { isLoggingOut = false }
        await signOut()
    }
}

/// Notification settings: one toggle per category, saved the moment it is flipped.
@MainActor
@Observable
public final class NotificationSettingsViewModel {
    public private(set) var state: Loadable<[NotificationPreference]> = .idle
    private var saving: Set<String> = []

    private let settings: any SettingsRepository
    private let toasts: ToastCenter

    public init(settings: any SettingsRepository, toasts: ToastCenter) {
        self.settings = settings
        self.toasts = toasts
    }

    public func load() async {
        guard case .idle = state else { return }
        state = .loading
        do {
            state = try await .loaded(settings.preferences())
        } catch {
            state = .failed(error)
        }
    }

    public func isSaving(_ preference: NotificationPreference) -> Bool {
        saving.contains(preference.key)
    }

    /// Flips at once, sends only this toggle, and flips back if the server says no.
    public func set(_ preference: NotificationPreference, enabled: Bool) async {
        guard case var .loaded(items) = state, let index = items.firstIndex(of: preference),
              !saving.contains(preference.key) else { return }
        let before = items
        items[index].isEnabled = enabled
        state = .loaded(items)
        saving.insert(preference.key)
        defer { saving.remove(preference.key) }
        do {
            state = try await .loaded(settings.setPreferences([preference.key: enabled]))
        } catch {
            state = .loaded(before)
            toasts.show(error)
        }
    }
}

/// Privacy policy or terms of service, from the CMS.
@MainActor
@Observable
public final class CmsPageViewModel {
    public let type: CmsPageType
    public private(set) var state: Loadable<CmsPage> = .idle
    private let settings: any SettingsRepository

    public init(type: CmsPageType, settings: any SettingsRepository) {
        self.type = type
        self.settings = settings
    }

    public func load() async {
        guard case .idle = state else { return }
        state = .loading
        do {
            state = try await .loaded(settings.page(type))
        } catch {
            state = .failed(error)
        }
    }
}

/// FAQ list.
@MainActor
@Observable
public final class FaqViewModel {
    public private(set) var state: Loadable<[Faq]> = .idle
    private let settings: any SettingsRepository

    public init(settings: any SettingsRepository) {
        self.settings = settings
    }

    public func load() async {
        guard case .idle = state else { return }
        state = .loading
        do {
            state = try await .loaded(settings.faqs())
        } catch {
            state = .failed(error)
        }
    }
}

/// "About Champz": the blurb and the company's email and WhatsApp from app-config.
@MainActor
@Observable
public final class AboutViewModel {
    public private(set) var state: Loadable<ServerSettings> = .idle
    private let content: any ContentRepository

    public init(content: any ContentRepository) {
        self.content = content
    }

    public func load() async {
        guard case .idle = state else { return }
        state = .loading
        do {
            state = try await .loaded(content.settings())
        } catch {
            state = .failed(error)
        }
    }

    public var emailURL: URL? {
        guard let email = state.value?.companyEmail, !email.isEmpty else { return nil }
        return URL(string: "mailto:\(email)")
    }

    /// Opens a chat with the number. (The current app put the number in the message text.)
    public var whatsAppURL: URL? {
        guard let number = state.value?.companyWhatsapp.filter(\.isNumber), !number.isEmpty else { return nil }
        return URL(string: "https://wa.me/\(number)")
    }
}

/// Deleting my account: a dry run first (what blocks it, what balance is at stake, the
/// reactivation window), then the delete. (The current app sent the delete blind, so any
/// player with a balance or an upcoming booking just saw "Delete Account Failed!".)
@MainActor
@Observable
public final class DeleteAccountViewModel {
    public private(set) var state: Loadable<DeletionState> = .idle
    public var disposition = BalanceDisposition.keep
    public var isConfirmPresented = false
    public private(set) var isDeleting = false
    /// One per attempt, so a retried request cannot move the balance twice.
    private let idempotencyKey = UUID().uuidString

    private let settings: any SettingsRepository
    private let toasts: ToastCenter
    private let deleted: @MainActor () async -> Void

    /// - Parameter deleted: called once the server confirms; every token is already dead, so it only clears this phone.
    public init(settings: any SettingsRepository, toasts: ToastCenter, deleted: @escaping @MainActor () async -> Void) {
        self.settings = settings
        self.toasts = toasts
        self.deleted = deleted
    }

    public func load() async {
        state = .loading
        do {
            state = try await .loaded(settings.deletionState())
        } catch {
            state = .failed(error)
        }
    }

    public func delete() async {
        guard let current = state.value, current.canDelete, !isDeleting else { return }
        isConfirmPresented = false
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await settings.deleteAccount(current.balance.isZero ? nil : disposition, idempotencyKey: idempotencyKey)
            await deleted()
        } catch {
            toasts.show(error)
            await load() // something changed (a new booking, a balance): show the latest
        }
    }
}
