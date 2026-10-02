import Foundation

public struct AuthTokens: Codable, Sendable, Equatable {
    public let access: String
    public let refresh: String

    public init(access: String, refresh: String) {
        self.access = access
        self.refresh = refresh
    }
}

/// Exchanges a refresh token for new tokens. Implemented in Data (`AuthRepository`), so
/// Core never defines an endpoint.
public protocol TokenRefreshing: Sendable {
    func refresh(using refreshToken: String) async throws(AppError) -> AuthTokens
}

/// Owns the tokens. Persists them in the Keychain, serves the access token to
/// `AuthInterceptor`, and performs single-flight refreshes. When a refresh fails for
/// good, the session ends and `onSessionEnded` fires so the UI returns to login.
public actor SessionStore {
    private static let key = "auth.tokens"

    private let store: any SecureStore
    private var tokens: AuthTokens?
    private var refresher: (any TokenRefreshing)?
    private var inFlightRefresh: Task<Bool, Never>?
    private var onSessionEnded: (@Sendable () async -> Void)?

    public init(store: any SecureStore) {
        self.store = store
    }

    /// Wire the refresher and the end-of-session hook once, from the composition root.
    public func configure(refresher: any TokenRefreshing, onSessionEnded: @escaping @Sendable () async -> Void) {
        self.refresher = refresher
        self.onSessionEnded = onSessionEnded
    }

    /// Loads persisted tokens. Returns whether a session exists.
    @discardableResult
    public func restore() -> Bool {
        if let data = try? store.data(for: Self.key), let saved = try? JSONDecoder().decode(
            AuthTokens.self,
            from: data
        ) {
            tokens = saved
        }
        return tokens != nil
    }

    public var accessToken: String? {
        tokens?.access
    }

    public var isSignedIn: Bool {
        tokens != nil
    }

    public func store(_ newTokens: AuthTokens) {
        tokens = newTokens
        do {
            try store.set(JSONEncoder().encode(newTokens), for: Self.key)
        } catch {
            Log.auth.error("Failed to persist tokens: \(String(describing: error), privacy: .public)")
        }
    }

    /// Forgets the session locally. Callers that want a server-side logout call the API first.
    public func clear() {
        tokens = nil
        try? store.remove(Self.key)
    }

    /// Refreshes once, however many callers ask at the same time. Returns true when a
    /// retry with the new access token makes sense.
    public func refresh() async -> Bool {
        if let inFlight = inFlightRefresh {
            return await inFlight.value
        }
        guard let current = tokens, let refresher else { return false }
        let staleRefreshToken = current.refresh

        let task = Task<Bool, Never> { [weak self] in
            do throws(AppError) {
                let fresh = try await refresher.refresh(using: staleRefreshToken)
                await self?.store(fresh)
                return true
            } catch {
                Log.auth.notice("Token refresh failed: \(String(describing: error), privacy: .public)")
                // Only a definitive rejection ends the session; a network blip does not.
                if case .unauthorized = error {
                    await self?.endSession()
                } else if case .forbidden = error {
                    await self?.endSession()
                }
                return false
            }
        }
        inFlightRefresh = task
        let result = await task.value
        inFlightRefresh = nil
        return result
    }

    private func endSession() async {
        clear()
        await onSessionEnded?()
    }
}
