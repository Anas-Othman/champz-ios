import Foundation

/// Notification preferences, the CMS pages and FAQs, and deleting my account.
enum SettingsAPI {
    static func preferences() -> Endpoint<[NotificationPreference]> {
        Endpoint(.get, "/api/v1/notifications/preferences/")
    }

    /// Only the toggles being changed. (The current app sent every toggle on every tap.)
    static func setPreferences(_ changes: [String: Bool]) -> Endpoint<[NotificationPreference]> {
        struct Item: Encodable {
            let key: String
            let isEnabled: Bool
        }
        struct Body: Encodable {
            let preferences: [Item]
        }
        let items = changes.sorted { $0.key < $1.key }.map { Item(key: $0.key, isEnabled: $0.value) }
        return Endpoint(.put, "/api/v1/notifications/preferences/").json(Body(preferences: items))
    }

    static func page(_ type: CmsPageType) -> Endpoint<CmsPage> {
        Endpoint(.get, "/api/v1/cms/pages/\(type.rawValue)/")
    }

    static func faqs() -> Endpoint<[Faq]> {
        Endpoint(.get, "/api/v1/cms/faqs/")
    }

    static func deletionState() -> Endpoint<DeletionState> {
        Endpoint(.get, "/api/v1/profile/deletion/")
    }

    /// No body when there is no balance; otherwise what to do with it.
    static func deleteAccount(_ disposition: BalanceDisposition?, idempotencyKey: String) -> Endpoint<NoContent> {
        let endpoint = Endpoint<NoContent>(.post, "/api/v1/profile/deletion/", idempotencyKey: idempotencyKey)
        // `{}` without a balance: the field may be missing but not null.
        return endpoint.json(disposition.map { ["balance_disposition": $0.rawValue] } ?? [:])
    }
}

public protocol SettingsRepository: Sendable {
    func preferences() async throws(AppError) -> [NotificationPreference]
    func setPreferences(_ changes: [String: Bool]) async throws(AppError) -> [NotificationPreference]
    func page(_ type: CmsPageType) async throws(AppError) -> CmsPage
    func faqs() async throws(AppError) -> [Faq]
    func deletionState() async throws(AppError) -> DeletionState
    func deleteAccount(_ disposition: BalanceDisposition?, idempotencyKey: String) async throws(AppError)
}

public struct LiveSettingsRepository: SettingsRepository {
    let http: any HTTPClientProtocol

    public init(http: any HTTPClientProtocol) {
        self.http = http
    }

    public func preferences() async throws(AppError) -> [NotificationPreference] {
        try await http.send(SettingsAPI.preferences())
    }

    public func setPreferences(_ changes: [String: Bool]) async throws(AppError) -> [NotificationPreference] {
        try await http.send(SettingsAPI.setPreferences(changes))
    }

    public func page(_ type: CmsPageType) async throws(AppError) -> CmsPage {
        try await http.send(SettingsAPI.page(type))
    }

    public func faqs() async throws(AppError) -> [Faq] {
        try await http.send(SettingsAPI.faqs())
    }

    public func deletionState() async throws(AppError) -> DeletionState {
        try await http.send(SettingsAPI.deletionState())
    }

    public func deleteAccount(_ disposition: BalanceDisposition?, idempotencyKey: String) async throws(AppError) {
        _ = try await http.send(SettingsAPI.deleteAccount(disposition, idempotencyKey: idempotencyKey))
    }
}
