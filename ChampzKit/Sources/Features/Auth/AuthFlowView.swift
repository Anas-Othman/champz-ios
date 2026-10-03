import SwiftUI

/// Root of the signed-out experience: welcome → identifier → code.
/// Has its own `NavigationStack`: nothing here exists once the player is signed in.
public struct AuthFlowView: View {
    /// Destinations inside the pre-sign-in flow. Each carries the data its screen needs.
    enum Route: Hashable {
        case enterIdentifier(AuthMode)
        case verifyCode(identifier: AuthIdentifier, challenge: OtpChallenge, mode: AuthMode)
    }

    let auth: any AuthRepository
    let toasts: ToastCenter
    /// Called after a successful verification. The app decides where to go (tabs or profile setup).
    let onSignedIn: @MainActor (AuthSession, AuthMode) -> Void

    @State private var path: [Route] = []

    public init(
        auth: any AuthRepository,
        toasts: ToastCenter,
        onSignedIn: @escaping @MainActor (AuthSession, AuthMode) -> Void
    ) {
        self.auth = auth
        self.toasts = toasts
        self.onSignedIn = onSignedIn
    }

    public var body: some View {
        NavigationStack(path: $path) {
            WelcomeView(
                onCreateAccount: { path.append(.enterIdentifier(.signUp)) },
                onLogin: { path.append(.enterIdentifier(.signIn)) }
            )
            .navigationDestination(for: Route.self) { route in
                switch route {
                case let .enterIdentifier(mode):
                    IdentifierEntryView(viewModel: IdentifierEntryViewModel(
                        mode: mode,
                        auth: auth,
                        toasts: toasts
                    ) { identifier, challenge in
                        path.append(.verifyCode(identifier: identifier, challenge: challenge, mode: mode))
                    })
                case let .verifyCode(identifier, challenge, mode):
                    OtpVerifyView(viewModel: OtpVerifyViewModel(
                        identifier: identifier, challenge: challenge, mode: mode,
                        auth: auth, toasts: toasts, onSignedIn: onSignedIn
                    ))
                }
            }
        }
        .tint(Color.ds.textPrimary)
    }
}
