import Foundation

/// Machine codes from the backend's error envelope (`conf/api_error_config.json`).
/// Named here so no feature compares against a magic number.
public enum APIErrorCode {
    public static let validation = "02007"
    public static let accountInactive = "02015"
    public static let throttled = "02020"
    public static let userAlreadyExists = "02022"
    public static let otpInvalid = "02023"
    public static let otpAttemptsExceeded = "02024"
    public static let paymentsPaused = "02050"
    public static let otpCooldown = "02053"
}
