import Core
import DesignSystem
import Domain
import Foundation
import Localization
import Observation

/// Screen logic for "Let's get started now!": pick phone or email, validate, request a code.
/// Pure logic: no SwiftUI import, fully testable with a fake `AuthRepository`.
@MainActor
@Observable
public final class IdentifierEntryViewModel {
    public enum Method: Hashable, CaseIterable {
        case phone, email
    }

    public let mode: AuthMode
    public var method: Method = .phone
    public var country = CountryDialCodes.qatar
    public var phoneNumber = ""
    public var email = ""
    public private(set) var isSubmitting = false
    /// Inline validation message, cleared as the player types.
    public private(set) var fieldError: String?

    private let auth: any AuthRepository
    private let toasts: ToastCenter
    private let onChallenge: @MainActor (AuthIdentifier, OtpChallenge) -> Void

    public init(
        mode: AuthMode,
        auth: any AuthRepository,
        toasts: ToastCenter,
        onChallenge: @escaping @MainActor (AuthIdentifier, OtpChallenge) -> Void
    ) {
        self.mode = mode
        self.auth = auth
        self.toasts = toasts
        self.onChallenge = onChallenge
    }

    /// The identifier the current input describes, or nil with `fieldError` set.
    public var identifier: AuthIdentifier? {
        switch method {
        case .phone:
            let digits = phoneNumber.filter(\.isNumber)
            return digits.count >= 6 ? .phone(countryCode: country.dial, number: digits) : nil
        case .email:
            let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return Self.isValidEmail(trimmed) ? .email(trimmed) : nil
        }
    }

    public func inputChanged() {
        fieldError = nil
    }

    public func submit() async {
        guard !isSubmitting else { return }
        guard let identifier else {
            fieldError = String(localized: method == .phone ? L10n.SignUp.pleaseEnterValidNumber : L10n.Auth
                .pleaseEnterValidEmail)
            return
        }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let challenge = switch mode {
            case .signIn: try await auth.requestSignIn(identifier)
            case .signUp: try await auth.requestSignUp(identifier)
            }
            onChallenge(identifier, challenge)
        } catch {
            toasts.show(error)
        }
    }

    /// Same rule as the current app: something@something.tld.
    static func isValidEmail(_ value: String) -> Bool {
        let pattern = #"^[^\s@<>()\[\],;:\\"]+(\.[^\s@<>()\[\],;:\\"]+)*@([A-Za-z0-9-]+\.)+[A-Za-z]{2,}$"#
        return value.range(of: pattern, options: .regularExpression) != nil
    }
}
