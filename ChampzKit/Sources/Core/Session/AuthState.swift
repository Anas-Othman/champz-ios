import Foundation
import Observation

/// Drives the root of the UI: login, profile setup or the tab bar. Owned by the
/// composition root; mutated only on the main actor.
@MainActor
@Observable
public final class AuthState {
    public enum Phase: Equatable, Sendable {
        /// Restoring tokens from the Keychain at launch.
        case loading
        case signedOut
        /// Signed in, but the profile is incomplete (sign-up goes straight to profile setup).
        case needsProfile
        case signedIn
    }

    public private(set) var phase: Phase = .loading

    public init() {}

    public func transition(to phase: Phase) {
        guard self.phase != phase else { return }
        Log.auth.info("Auth phase: \(String(describing: phase), privacy: .public)")
        self.phase = phase
    }
}
