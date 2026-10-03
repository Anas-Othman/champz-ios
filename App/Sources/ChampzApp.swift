import ChampzKit
import SwiftUI

@main
struct ChampzApp: App {
    @State private var container: AppContainer

    init() {
        FontRegistrar.registerAll()
        let config = AppConfig.fromBundle()
        _container = State(initialValue: AppContainer(config: config))
        // TODO(foundation): start Sentry with config.sentryDSN and route DecodingDiagnostics there.
        DecodingDiagnostics.install { issue in
            Log.decoding.notice("\(issue.path, privacy: .public): \(issue.detail, privacy: .public)")
        }
        let build = "\(config.environment.rawValue) v\(config.appVersion) (\(config.buildNumber))"
        Log.app.info("Launch \(build, privacy: .public)")
    }

    var body: some Scene {
        WindowGroup {
            RootView(container: container)
                // Parity: the current app is light-only. Tokens can grow dark variants later.
                .preferredColorScheme(.light)
                .toastHost(container.toasts)
                .task { await container.bootstrap() }
                .onOpenURL { url in container.open(url: url) }
        }
    }
}
