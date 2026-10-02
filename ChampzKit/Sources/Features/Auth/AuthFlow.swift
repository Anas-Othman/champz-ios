import Core
import DesignSystem
import Domain
import Localization
import Navigation
import SwiftUI

/// What the auth feature needs from the outside world. The App target builds this
/// from `AppContainer`; tests build it with a fake repository.
public struct AuthFlowDependencies: Sendable {
    public let auth: any AuthRepository
    public let toasts: ToastCenter
    /// Called after a successful verification. The app decides where to go (tabs or profile setup).
    public let onSignedIn: @MainActor @Sendable (AuthSession, AuthMode) -> Void

    public init(
        auth: any AuthRepository,
        toasts: ToastCenter,
        onSignedIn: @escaping @MainActor @Sendable (AuthSession, AuthMode) -> Void
    ) {
        self.auth = auth
        self.toasts = toasts
        self.onSignedIn = onSignedIn
    }
}

/// Destinations inside the pre-sign-in flow. This stack is separate from the tab
/// router: nothing here exists once the player is signed in.
enum AuthRoute: Hashable {
    case enterIdentifier(AuthMode)
    case verifyCode(identifier: AuthIdentifier, challenge: OtpChallenge, mode: AuthMode)
}

/// Root of the signed-out experience: welcome → identifier → code.
public struct AuthFlowView: View {
    private let dependencies: AuthFlowDependencies
    @State private var path: [AuthRoute] = []

    public init(dependencies: AuthFlowDependencies) {
        self.dependencies = dependencies
    }

    public var body: some View {
        NavigationStack(path: $path) {
            WelcomeView(
                onCreateAccount: { path.append(.enterIdentifier(.signUp)) },
                onLogin: { path.append(.enterIdentifier(.signIn)) }
            )
            .navigationDestination(for: AuthRoute.self) { route in
                switch route {
                case let .enterIdentifier(mode):
                    IdentifierEntryView(
                        viewModel: IdentifierEntryViewModel(
                            mode: mode,
                            auth: dependencies.auth,
                            toasts: dependencies.toasts
                        ) { identifier, challenge in
                            path.append(.verifyCode(identifier: identifier, challenge: challenge, mode: mode))
                        }
                    )
                case let .verifyCode(identifier, challenge, mode):
                    OtpVerifyView(
                        viewModel: OtpVerifyViewModel(
                            identifier: identifier,
                            challenge: challenge,
                            mode: mode,
                            auth: dependencies.auth,
                            toasts: dependencies.toasts,
                            onSignedIn: dependencies.onSignedIn
                        )
                    )
                }
            }
        }
        .tint(Color.ds.textPrimary)
    }
}
