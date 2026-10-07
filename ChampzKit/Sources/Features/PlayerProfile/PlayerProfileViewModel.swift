import Foundation
import Observation

/// Another player's profile: their card and statistics, nothing private.
@MainActor
@Observable
public final class PlayerProfileViewModel {
    public let playerID: PlayerID
    public private(set) var state: Loadable<PlayerStats> = .idle

    private let profiles: any ProfileRepository
    private let toasts: ToastCenter

    public init(playerID: PlayerID, profiles: any ProfileRepository, toasts: ToastCenter) {
        self.playerID = playerID
        self.profiles = profiles
        self.toasts = toasts
    }

    public func load() async {
        guard case .idle = state else { return }
        state = .loading
        await reload()
    }

    public func reload() async {
        do {
            state = try await .loaded(profiles.stats(playerID))
        } catch {
            if case .loaded = state {
                toasts.show(error)
            } else {
                state = .failed(error)
            }
        }
    }
}

/// The My Stats tab: the signed-in player's own stats, plus their wallet balance and Edit Profile.
@MainActor
@Observable
public final class MyStatsViewModel {
    public struct Content: Hashable, Sendable {
        public let stats: PlayerStats
        public let balance: Money
    }

    public private(set) var state: Loadable<Content> = .idle

    private let profiles: any ProfileRepository
    private let payments: any PaymentRepository
    private let router: AppRouter
    private let toasts: ToastCenter

    public init(
        profiles: any ProfileRepository,
        payments: any PaymentRepository,
        router: AppRouter,
        toasts: ToastCenter
    ) {
        self.profiles = profiles
        self.payments = payments
        self.router = router
        self.toasts = toasts
    }

    public func load() async {
        guard case .idle = state else { return }
        state = .loading
        await reload()
    }

    /// Profile first (it says who "me" is), then my stats and wallet together.
    /// Also runs after Edit Profile saves, so the screen never shows stale or zeroed stats.
    public func reload() async {
        do {
            let me = try await profiles.profile()
            async let stats = profiles.stats(me.id)
            async let wallet = payments.wallet()
            state = try await .loaded(Content(stats: stats, balance: wallet.money))
        } catch let error as AppError {
            if case .loaded = state {
                toasts.show(error)
            } else {
                state = .failed(error)
            }
        } catch {
            state = .failed(.unknown)
        }
    }

    public func editProfile() {
        router.present(.editProfile)
    }

    public func openWallet() {
        router.push(.walletHistory)
    }
}
