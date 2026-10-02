import Core
import DesignSystem
import Domain
import Foundation
import Localization
import Observation

/// Screen logic for the code screen: a six-digit code, a server-driven resend timer,
/// verify, resend. On success the app is told which flow finished.
@MainActor
@Observable
public final class OtpVerifyViewModel {
    public static let codeLength = 6

    public let identifier: AuthIdentifier
    public let mode: AuthMode
    public private(set) var challenge: OtpChallenge
    public var code = ""
    public private(set) var isVerifying = false
    public private(set) var isResending = false
    /// Seconds until "Request a new code" becomes tappable. Starts at the server's `resend_after`.
    public private(set) var resendSeconds = 0

    private let auth: any AuthRepository
    private let toasts: ToastCenter
    private let onSignedIn: @MainActor (AuthSession, AuthMode) -> Void
    @ObservationIgnored private var countdown: Task<Void, Never>?

    public init(
        identifier: AuthIdentifier,
        challenge: OtpChallenge,
        mode: AuthMode,
        auth: any AuthRepository,
        toasts: ToastCenter,
        onSignedIn: @escaping @MainActor (AuthSession, AuthMode) -> Void
    ) {
        self.identifier = identifier
        self.challenge = challenge
        self.mode = mode
        self.auth = auth
        self.toasts = toasts
        self.onSignedIn = onSignedIn
        startCountdown(from: challenge.resendAfter)
    }

    public var canResend: Bool {
        resendSeconds == 0 && !isResending && !isVerifying
    }

    public var canVerify: Bool {
        code.count == Self.codeLength && !isVerifying
    }

    /// "0:42" for the resend label.
    public var resendCountdownLabel: String {
        String(format: "%d:%02d", resendSeconds / 60, resendSeconds % 60)
    }

    public func verify() async {
        guard code.count == Self.codeLength else {
            toasts.show(Toast(.error, L10n.Auth.pleaseEnterValidOtp))
            return
        }
        guard !isVerifying else { return }
        isVerifying = true
        defer { isVerifying = false }
        do {
            let session = try await auth.verify(identifier, code: code)
            stopCountdown()
            onSignedIn(session, mode)
        } catch {
            code = ""
            toasts.show(error)
        }
    }

    public func resend() async {
        guard canResend else { return }
        isResending = true
        defer { isResending = false }
        do {
            challenge = try await auth.resendCode(identifier)
            startCountdown(from: challenge.resendAfter)
            toasts.show(Toast(.success, L10n.Auth.otpResent))
        } catch {
            // A cooldown tells us exactly how long to wait; honour it instead of letting the player hammer the button.
            if case let .rateLimited(_, retryAfter?) = error {
                startCountdown(from: retryAfter)
            }
            toasts.show(error)
        }
    }

    public func stopCountdown() {
        countdown?.cancel()
        countdown = nil
    }

    private func startCountdown(from seconds: Int) {
        stopCountdown()
        resendSeconds = max(0, seconds)
        guard resendSeconds > 0 else { return }
        countdown = Task { [weak self] in
            while let self, resendSeconds > 0, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                resendSeconds -= 1
            }
        }
    }
}
