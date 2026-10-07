import SwiftUI
import Testing
import UIKit
@testable import ChampzKit

/// The join-flow bug: a screen buried under pushed screens must still refresh when data changes.
@MainActor
struct DataChangesNavigationTests {
    @Observable
    final class Probe {
        var refreshes = 0
    }

    struct Root: View {
        @Environment(DataChanges.self) private var changes: DataChanges?
        let probe: Probe
        @Binding var path: [Int]

        var body: some View {
            NavigationStack(path: $path) {
                Text(verbatim: "match")
                    .onChange(of: changes?.matchesVersion) { probe.refreshes += 1 }
                    .navigationDestination(for: Int.self) { Text(verbatim: "screen \($0)") }
            }
        }
    }

    @Test func screenBelowInTheStackRefreshesWhenMatchesChange() async throws {
        let changes = DataChanges()
        let probe = Probe()
        var path: [Int] = []
        let binding = Binding(get: { path }, set: { path = $0 })
        let host = UIHostingController(rootView: Root(probe: probe, path: binding).environment(changes))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.makeKeyAndVisible()

        path = [1, 2, 3] // registration, confirm, done on top of the match
        host.rootView = Root(probe: probe, path: binding).environment(changes)
        try await Task.sleep(for: .milliseconds(300))

        changes.matchesChanged() // the join completed
        try await Task.sleep(for: .milliseconds(300))
        #expect(probe.refreshes == 1)
    }

    @Test func completedJoinAnnouncesTheChange() async {
        let matches = FakeMatchRepository()
        await matches.set(join: .success(joined))
        let payments = FakePaymentRepository()
        await payments.set(balance: 100)
        let changes = DataChanges()
        let viewModel = JoinConfirmViewModel(
            draft: joinDraft(),
            matches: matches,
            payments: payments,
            content: FakeContentRepository(),
            router: AppRouter(),
            toasts: ToastCenter(),
            changes: changes
        )
        await viewModel.checkout.load()
        viewModel.checkout.useWallet = true
        await viewModel.checkout.pay()
        #expect(changes.matchesVersion == 1)
    }
}
