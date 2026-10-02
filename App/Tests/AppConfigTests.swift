import Testing
@testable import Champz

struct AppConfigTests {
    @Test func bundleCarriesEnvironmentAndBaseURL() {
        let config = AppConfig.fromBundle()
        #expect(config.apiBaseURL.scheme == "https" || config.apiBaseURL.scheme == "http")
        #expect(!config.appVersion.isEmpty)
    }
}
