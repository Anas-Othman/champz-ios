import Foundation

/// Typed view of the values the active `.xcconfig` put into Info.plist. Read once at launch.
struct AppConfig: Sendable {
    enum Environment: String, Sendable {
        case local, staging, production
    }

    let environment: Environment
    let apiBaseURL: URL
    let sentryDSN: String?
    let appVersion: String
    let buildNumber: String

    static func fromBundle(_ bundle: Bundle = .main) -> AppConfig {
        let info = bundle.infoDictionary ?? [:]
        guard
            let environmentRaw = info["ChampzEnvironment"] as? String,
            let environment = Environment(rawValue: environmentRaw),
            let baseURLString = info["ChampzAPIBaseURL"] as? String,
            let apiBaseURL = URL(string: baseURLString)
        else {
            // A build without its xcconfig is a build error, not a runtime condition.
            fatalError("Info.plist is missing ChampzEnvironment / ChampzAPIBaseURL — check Config/*.xcconfig")
        }
        let dsn = (info["ChampzSentryDSN"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        return AppConfig(
            environment: environment,
            apiBaseURL: apiBaseURL,
            sentryDSN: dsn,
            appVersion: info["CFBundleShortVersionString"] as? String ?? "0",
            buildNumber: info["CFBundleVersion"] as? String ?? "0"
        )
    }

    static let preview = AppConfig(
        environment: .local,
        apiBaseURL: URL(string: "https://api-staging.champz.me")!,
        sentryDSN: nil,
        appVersion: "2.0.0",
        buildNumber: "1"
    )
}
