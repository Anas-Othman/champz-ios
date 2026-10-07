import Foundation

/// Name, email and phone collected before any booking or join. One model, one set of
/// rules, used by every paid flow (current app's registration validation).
public struct BookingInfo: Hashable, Sendable {
    public enum Field: Hashable, Sendable { case name, email, phone }

    public var name = ""
    public var email = ""
    public var country = CountryDialCodes.qatar
    public var phone = ""

    /// The current app limits the local number to 8 digits (Qatar).
    public static let phoneLength = 8

    public init() {}

    /// Prefilled from the signed-in account.
    public init(user: AccountUser) {
        name = user.fullName
        email = user.email
        phone = user.phone
        if let dial = CountryDialCodes.byDial(user.countryCode) {
            country = dial
        }
    }

    public var trimmedName: String {
        name.trimmingCharacters(in: .whitespaces)
    }

    public var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespaces)
    }

    /// "+974 55551234", as the backend receives `booking_mobile_no`.
    public var formattedPhone: String {
        "\(country.dial) \(phone.trimmingCharacters(in: .whitespaces))"
    }

    /// Empty when valid; otherwise one message per bad field.
    public func validate() -> [Field: String] {
        var errors: [Field: String] = [:]
        if trimmedName.isEmpty {
            errors[.name] = String(localized: L10n.Profile.pleaseEnterName)
        }
        if !Validation.isValidEmail(trimmedEmail) {
            errors[.email] = String(localized: L10n.Auth.pleaseEnterValidEmail)
        }
        let digits = phone.trimmingCharacters(in: .whitespaces)
        if digits.isEmpty {
            errors[.phone] = String(localized: L10n.Tournament.pleaseEnterPhoneNumber)
        } else if digits.count < Self.phoneLength {
            errors[.phone] = String(localized: L10n.Tournament.pleaseEnterValidPhoneNumber)
        }
        return errors
    }
}
