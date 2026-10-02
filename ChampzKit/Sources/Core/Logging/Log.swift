import os

/// One logger per concern. Never log tokens, card data or personal data; the
/// `no_print` lint rule keeps `print` out of the codebase.
public enum Log {
    private static let subsystem = "me.champz.app"

    public static let app = Logger(subsystem: subsystem, category: "app")
    public static let network = Logger(subsystem: subsystem, category: "network")
    public static let auth = Logger(subsystem: subsystem, category: "auth")
    public static let decoding = Logger(subsystem: subsystem, category: "decoding")
    public static let payments = Logger(subsystem: subsystem, category: "payments")
    public static let navigation = Logger(subsystem: subsystem, category: "navigation")
}
