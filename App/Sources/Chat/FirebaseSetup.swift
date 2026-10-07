import ChampzKit
import FirebaseCore
import Foundation

/// Starts Firebase from the GoogleService-Info file for this environment, if the build has one.
/// The files are git-ignored: drop them into App/Resources as
/// `GoogleService-Info-Staging.plist` (Local and Staging) and `GoogleService-Info-Production.plist`.
/// Without one the app still runs; chat says it is unavailable.
enum FirebaseSetup {
    @MainActor private(set) static var isConfigured = false

    @MainActor
    static func configure(for environment: AppConfig.Environment) {
        guard !isConfigured else { return }
        let name = environment == .production ? "GoogleService-Info-Production" : "GoogleService-Info-Staging"
        guard let path = Bundle.main.path(forResource: name, ofType: "plist"),
              let options = FirebaseOptions(contentsOfFile: path)
        else {
            Log.app.notice("Firebase not configured: \(name, privacy: .public).plist is not in the bundle")
            return
        }
        FirebaseApp.configure(options: options)
        isConfigured = true
    }
}
