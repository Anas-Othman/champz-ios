import Foundation
import Testing
@testable import ChampzKit

/// Scripted `SettingsRepository`.
actor FakeSettingsRepository: SettingsRepository {
    private(set) var preferenceWrites: [[String: Bool]] = []
    private(set) var deletions: [(BalanceDisposition?, String)] = []
    var failPreferences = false
    var state: DeletionState = makeDeletionState(balance: "0.00", blockers: "[]")

    func set(failPreferences: Bool) {
        self.failPreferences = failPreferences
    }

    func set(state: DeletionState) {
        self.state = state
    }

    func preferences() async throws(AppError) -> [NotificationPreference] {
        [
            .decode(#"{"key": "all_module", "title": "All notifications", "is_enabled": true}"#),
            .decode(#"{"key": "matches", "title": "Matches", "is_enabled": false}"#),
        ]
    }

    func setPreferences(_ changes: [String: Bool]) async throws(AppError) -> [NotificationPreference] {
        preferenceWrites.append(changes)
        if failPreferences {
            throw .offline
        }
        return try await preferences().map { item in
            var copy = item
            copy.isEnabled = changes[item.key] ?? item.isEnabled
            return copy
        }
    }

    func page(_: CmsPageType) async throws(AppError) -> CmsPage {
        .decode(#"{"name": "Privacy Policy", "description": "<p>Hello</p>"}"#)
    }

    func faqs() async throws(AppError) -> [Faq] {
        []
    }

    func deletionState() async throws(AppError) -> DeletionState {
        state
    }

    func deleteAccount(_ disposition: BalanceDisposition?, idempotencyKey: String) async throws(AppError) {
        deletions.append((disposition, idempotencyKey))
    }
}

func makeDeletionState(balance: String, blockers: String) -> DeletionState {
    .decode(
        #"{"can_delete": \#(blockers == "[]"), "blockers": \#(blockers), "wallet_balance": "\#(balance)", "#
            + #""currency": "QAR", "reactivation_window_days": 30}"#
    )
}

struct SettingsAPITests {
    @Test func deletingWithoutABalanceSendsAnEmptyBody() throws {
        let empty = try #require(SettingsAPI.deleteAccount(nil, idempotencyKey: "k").body)
        #expect(String(bytes: empty, encoding: .utf8) == "{}") // not {"balance_disposition": null}
        let keep = try #require(SettingsAPI.deleteAccount(.keep, idempotencyKey: "k").body)
        #expect(String(bytes: keep, encoding: .utf8) == #"{"balance_disposition":"keep"}"#)
        #expect(SettingsAPI.deleteAccount(.giveToChampz, idempotencyKey: "k").idempotencyKey == "k")
    }

    @Test func onlyTheFlippedToggleIsSent() throws {
        let data = try #require(SettingsAPI.setPreferences(["matches": true]).body)
        // Compare the decoded JSON: the encoder does not promise a key order.
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: [[String: Any]]])
        let items = try #require(json["preferences"])
        #expect(items.count == 1)
        #expect(items.first?["key"] as? String == "matches")
        #expect(items.first?["is_enabled"] as? Bool == true)
    }

    @Test func htmlFallbackKeepsParagraphs() {
        #expect("<p>One</p><p>Two<br>Three</p>".strippingHTMLTags == "One\nTwo\nThree")
    }
}

@MainActor
struct SettingsViewModelTests {
    @Test func aFailedToggleFlipsBack() async throws {
        let repository = FakeSettingsRepository()
        let viewModel = NotificationSettingsViewModel(settings: repository, toasts: ToastCenter())
        await viewModel.load()
        let matches = try #require(viewModel.state.value?[1])
        await viewModel.set(matches, enabled: true)
        #expect(viewModel.state.value?[1].isEnabled == true)
        #expect(await repository.preferenceWrites == [["matches": true]])

        await repository.set(failPreferences: true)
        try await viewModel.set(#require(viewModel.state.value?[1]), enabled: false)
        #expect(viewModel.state.value?[1].isEnabled == true) // back to what the server has
    }

    @Test func logOutEndsTheSessionOnThisPhone() async {
        var signedOut = false
        let viewModel = SettingsViewModel(
            payments: FakePaymentRepository(), router: AppRouter(), versionText: "Champz 2.0.0 (1)"
        ) { signedOut = true }
        await viewModel.logOut()
        #expect(signedOut)
    }

    @Test func whatsAppOpensAChatWithTheNumber() async {
        let viewModel = AboutViewModel(content: FakeContentRepository(
            settingsJSON: #"{"company_email": "hello@champz.me", "company_whatsapp": "+974 5555 1234"}"#
        ))
        await viewModel.load()
        #expect(viewModel.whatsAppURL?.absoluteString == "https://wa.me/97455551234")
        #expect(viewModel.emailURL?.absoluteString == "mailto:hello@champz.me")
    }
}

@MainActor
struct DeleteAccountViewModelTests {
    private struct Harness {
        let viewModel: DeleteAccountViewModel
        let repository: FakeSettingsRepository
        let wasDeleted: () -> Bool
    }

    private func make(_ state: DeletionState) async -> Harness {
        let repository = FakeSettingsRepository()
        await repository.set(state: state)
        var deleted = false
        let viewModel = DeleteAccountViewModel(settings: repository, toasts: ToastCenter()) { deleted = true }
        await viewModel.load()
        return Harness(viewModel: viewModel, repository: repository, wasDeleted: { deleted })
    }

    @Test func aBalanceIsSentWithTheChosenDisposition() async {
        let harness = await make(makeDeletionState(balance: "40.00", blockers: "[]"))
        harness.viewModel.disposition = .giveToChampz
        await harness.viewModel.delete()
        #expect(await harness.repository.deletions.first?.0 == .giveToChampz)
        #expect(harness.wasDeleted())
    }

    @Test func noBalanceSendsNoDisposition() async {
        let harness = await make(makeDeletionState(balance: "0.00", blockers: "[]"))
        await harness.viewModel.delete()
        #expect(await harness.repository.deletions.count == 1)
        #expect(await harness.repository.deletions.first?.0 == nil)
    }

    @Test func blockersMeanNothingIsSent() async {
        let harness = await make(makeDeletionState(
            balance: "0.00",
            blockers: #"[{"kind": "club", "label": "Falcons", "on": null}]"#
        ))
        #expect(harness.viewModel.state.value?.blockers.first?.isClub == true)
        await harness.viewModel.delete()
        #expect(await harness.repository.deletions.isEmpty)
        #expect(!harness.wasDeleted())
    }
}
