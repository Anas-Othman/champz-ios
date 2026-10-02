import Foundation

/// Adds the headers every request carries: language, app version, build, platform.
public struct HeadersInterceptor: RequestInterceptor {
    private let appVersion: String
    private let buildNumber: String

    public init(appVersion: String, buildNumber: String) {
        self.appVersion = appVersion
        self.buildNumber = buildNumber
    }

    public func prepare(_ request: URLRequest, context: RequestContext) async throws(AppError) -> URLRequest {
        var request = request
        request.setValue(Locale.preferredLanguages.first ?? "en", forHTTPHeaderField: "Accept-Language")
        request.setValue(appVersion, forHTTPHeaderField: "X-App-Version")
        request.setValue(buildNumber, forHTTPHeaderField: "X-App-Build")
        request.setValue("ios", forHTTPHeaderField: "X-App-Platform")
        return request
    }
}
