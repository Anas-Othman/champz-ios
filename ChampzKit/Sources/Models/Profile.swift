import Foundation

/// `GET /api/v1/profile/` — the signed-in player's own profile.
public struct PlayerProfile: Decodable, Hashable, Sendable, Identifiable {
    public let id: PlayerID
    @DefaultEmpty public var firstName: String
    @DefaultEmpty public var lastName: String
    @DefaultEmpty public var fullName: String
    @DefaultEmpty public var email: String
    /// "+974" (sometimes stored without the plus).
    @DefaultEmpty public var countryCode: String
    @DefaultEmpty public var phone: String
    @DefaultEmpty public var avatarUrl: String
    @DefaultEmpty public var gender: String
    /// "yyyy-MM-dd", empty when unset.
    @DefaultEmpty public var dateOfBirth: String
    public var nationality: Nationality?
    public var city: City?
    public var position: Position?
    @DefaultFalse public var isAvailable: Bool
    @DefaultFalse public var isProfileComplete: Bool
    @DefaultEmpty public var clubName: String

    /// "+974", whichever way it was stored; empty when unset.
    public var dialCode: String {
        let code = countryCode.trimmingCharacters(in: .whitespaces)
        guard !code.isEmpty else { return "" }
        return code.hasPrefix("+") ? code : "+" + code
    }

    public var birthDate: Date? {
        DateOfBirth.date(from: dateOfBirth)
    }
}

/// `GET /api/v1/countries/` — a country as the nationality picker shows it.
public struct Nationality: Decodable, Hashable, Sendable, Identifiable {
    public let id: CountryID
    @DefaultEmpty public var code: String
    @DefaultEmpty public var name: String
    /// "Qatari".
    @DefaultEmpty public var nationality: String

    /// Flag emoji from the ISO code ("QA" → 🇶🇦); empty without a code.
    public var flag: String {
        code.count == 2 ? CountryDialCode(code: code.uppercased(), dial: "").flag : ""
    }

    /// The label shown; falls back to the country name.
    public var label: String {
        nationality.isEmpty ? name : nationality
    }
}

/// `GET /api/v1/positions/`.
public struct Position: Decodable, Hashable, Sendable, Identifiable {
    public let id: PositionID
    @DefaultEmpty public var code: String
    @DefaultEmpty public var name: String
}

public struct City: Decodable, Hashable, Sendable, Identifiable {
    public let id: CityID
    @DefaultEmpty public var name: String
}

/// A phone number with its dialling prefix.
public struct PhoneNumber: Hashable, Sendable {
    public let dial: String
    public let number: String

    public init(dial: String, number: String) {
        self.dial = dial
        self.number = number
    }
}

/// The changes "Save Changes" sends. Only what the screen collects; nil means "leave as is".
public struct ProfileUpdate: Hashable, Sendable {
    public var fullName: String
    /// Only for a player who has no email yet.
    public var email: String?
    /// Only for a player who has no phone yet.
    public var phone: PhoneNumber?
    public var dateOfBirth: Date?
    public var nationalityID: CountryID?
    public var positionID: PositionID?
    /// JPEG of a newly picked photo.
    public var avatar: Data?

    public init(
        fullName: String,
        email: String? = nil,
        phone: PhoneNumber? = nil,
        dateOfBirth: Date? = nil,
        nationalityID: CountryID? = nil,
        positionID: PositionID? = nil,
        avatar: Data? = nil
    ) {
        self.fullName = fullName
        self.email = email
        self.phone = phone
        self.dateOfBirth = dateOfBirth
        self.nationalityID = nationalityID
        self.positionID = positionID
        self.avatar = avatar
    }

    /// The text parts of the multipart body.
    /// The one name box is split into first and last name at the first space. (The current app
    /// wrote the whole name into `first_name` and kept the old last name, so "Anas E" became "Anas E E".)
    var fields: [String: String] {
        let parts = fullName.trimmingCharacters(in: .whitespaces).split(separator: " ", maxSplits: 1).map(String.init)
        var fields = ["first_name": parts.first ?? "", "last_name": parts.count > 1 ? parts[1] : ""]
        fields["email"] = email
        fields["phone"] = phone?.number
        fields["country_code"] = phone?.dial
        fields["date_of_birth"] = dateOfBirth.map(DateOfBirth.string(from:))
        fields["nationality"] = nationalityID?.raw
        fields["position"] = positionID?.raw
        return fields
    }
}

/// Date of birth as the API sends it: a calendar day ("yyyy-MM-dd") with no time zone.
public enum DateOfBirth {
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    public static func date(from text: String) -> Date? {
        formatter.date(from: String(text.prefix(10)))
    }

    public static func string(from date: Date) -> String {
        formatter.string(from: date)
    }

    /// Players must be at least 6 and at most about 86 (the current app's picker range).
    public static func allowedRange(now: Date = .now) -> ClosedRange<Date> {
        let calendar = Calendar(identifier: .gregorian)
        let latest = calendar.date(byAdding: .year, value: -6, to: now) ?? now
        let earliest = calendar.date(byAdding: .year, value: -80, to: latest) ?? latest
        return earliest ... latest
    }
}
