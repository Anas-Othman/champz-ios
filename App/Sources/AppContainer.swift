import AuthFeature
import Core
import Data
import DesignSystem
import Domain
import Navigation
import SwiftUI

/// The composition root: the only type that knows every module. Builds the live
/// dependencies once and hands view models what they need through `make…` factories.
@MainActor
final class AppContainer {
    let config: AppConfig
    let session: SessionStore
    let authState = AuthState()
    let router = AppRouter()
    let events = AppEvents()
    let toasts = ToastCenter()

    /// Authenticated client used by every repository.
    let http: HTTPClient

    // Repositories: one line each, protocol-typed so features never see the Live types.
    private(set) lazy var auth: any AuthRepository = LiveAuthRepository(http: http, session: session)

    init(config: AppConfig, secureStore: any SecureStore = KeychainStore()) {
        self.config = config
        session = SessionStore(store: secureStore)

        // Full request/response dumps in debug builds only; release logs the one-line summary.
        #if DEBUG
            let logging = LoggingInterceptor(logsBodies: true)
        #else
            let logging = LoggingInterceptor()
        #endif

        // Refreshes go through a client WITHOUT the auth interceptor, so they cannot recurse.
        let anonymous = HTTPClient(
            baseURL: config.apiBaseURL,
            interceptors: [
                HeadersInterceptor(appVersion: config.appVersion, buildNumber: config.buildNumber),
                logging,
            ]
        )
        http = HTTPClient(
            baseURL: config.apiBaseURL,
            interceptors: [
                HeadersInterceptor(appVersion: config.appVersion, buildNumber: config.buildNumber),
                AuthInterceptor(session: session),
                logging,
            ]
        )

        let authState = authState
        Task {
            await session.configure(refresher: LiveTokenRefresher(http: anonymous)) {
                await MainActor.run { authState.transition(to: .signedOut) }
            }
        }
    }

    /// Restores the session from the Keychain and settles the root UI.
    /// A restored token is checked against `/auth/me`; only a definitive rejection signs out,
    /// an offline launch stays signed in (the current app behaves the same).
    func bootstrap() async {
        guard await session.restore() else {
            authState.transition(to: .signedOut)
            return
        }
        do {
            _ = try await auth.currentUser()
            authState.transition(to: .signedIn)
        } catch .unauthorized, .forbidden {
            await session.clear()
            authState.transition(to: .signedOut)
        } catch {
            Log.auth.notice("Session check failed (\(String(describing: error), privacy: .public)); staying signed in")
            authState.transition(to: .signedIn)
        }
        router.replayPendingDeepLink()
    }

    /// What the auth feature needs. Sign-in lands in the tabs; sign-up goes to profile setup first.
    func makeAuthFlow() -> AuthFlowDependencies {
        AuthFlowDependencies(auth: auth, toasts: toasts) { [weak self] session, mode in
            guard let self else { return }
            let via = String(describing: mode)
            Log.auth.info("Signed in as \(session.user.id, privacy: .public) via \(via, privacy: .public)")
            authState.transition(to: mode == .signUp ? .needsProfile : .signedIn)
            router.replayPendingDeepLink()
        }
    }

    func signOut() async {
        await session.clear()
        router.popToRoot()
        router.dismissSheet()
        authState.transition(to: .signedOut)
    }

    func open(url: URL) {
        guard let link = DeepLinkParser.parse(url) else {
            Log.navigation.notice("Unrecognised link: \(url.absoluteString, privacy: .public)")
            return
        }
        router.open(link, isSignedIn: authState.phase == .signedIn)
    }
}

extension AppContainer {
    /// For `#Preview` and the app test bundle: memory-only storage, no Keychain prompts.
    static let preview = AppContainer(config: .preview, secureStore: InMemorySecureStore())
}
