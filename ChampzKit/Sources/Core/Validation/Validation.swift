import Foundation

/// Input rules shared by every form (sign-in, booking info, guest email…).
public enum Validation {
    /// Same rule as the current app: something@something.tld.
    public static func isValidEmail(_ value: String) -> Bool {
        let pattern = #"^[^\s@<>()\[\],;:\\"]+(\.[^\s@<>()\[\],;:\\"]+)*@([A-Za-z0-9-]+\.)+[A-Za-z]{2,}$"#
        return value.range(of: pattern, options: .regularExpression) != nil
    }
}
