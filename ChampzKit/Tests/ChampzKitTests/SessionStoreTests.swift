import Foundation
import Testing
@testable import ChampzKit

/// Counts refresh calls and answers after a short delay so concurrent callers overlap.
private actor CountingRefresher: TokenRefreshing {
    private(set) var calls = 0
    var outcome: Result<AuthTokens, AppError> = .success(AuthTokens(access: "a2", refresh: "r2"))

    func set(_ outcome: Result<AuthTokens, AppError>) {
        self.outcome = outcome
    }

    func refresh(using refreshToken: String) async throws(AppError) -> AuthTokens {
        calls += 1
        try? await Task.sleep(for: .milliseconds(50))
        return try outcome.get()
    }
}

private actor Flag {
    var ended = false
    func set() {
        ended = true
    }
}

struct SessionStoreTests {
    @Test func concurrent401sShareOneRefresh() async {
        let store = SessionStore(store: InMemorySecureStore())
        let refresher = CountingRefresher()
        await store.configure(refresher: refresher) {}
        await store.store(AuthTokens(access: "a1", refresh: "r1"))

        async let first = store.refresh()
        async let second = store.refresh()
        async let third = store.refresh()
        let results = await [first, second, third]

        #expect(results == [true, true, true])
        #expect(await refresher.calls == 1)
        #expect(await store.accessToken == "a2")
    }

    @Test func rejectedRefreshEndsSession() async {
        let store = SessionStore(store: InMemorySecureStore())
        let refresher = CountingRefresher()
        await refresher.set(.failure(.unauthorized))
        let flag = Flag()
        await store.configure(refresher: refresher) { await flag.set() }
        await store.store(AuthTokens(access: "a1", refresh: "r1"))

        let ok = await store.refresh()

        #expect(!ok)
        #expect(await flag.ended)
        #expect(await store.accessToken == nil)
    }

    @Test func offlineRefreshKeepsSession() async {
        let store = SessionStore(store: InMemorySecureStore())
        let refresher = CountingRefresher()
        await refresher.set(.failure(.offline))
        let flag = Flag()
        await store.configure(refresher: refresher) { await flag.set() }
        await store.store(AuthTokens(access: "a1", refresh: "r1"))

        let ok = await store.refresh()

        #expect(!ok)
        #expect(await !flag.ended)
        #expect(await store.accessToken == "a1")
    }

    @Test func tokensPersistAcrossInstances() async {
        let secure = InMemorySecureStore()
        let first = SessionStore(store: secure)
        await first.store(AuthTokens(access: "a", refresh: "r"))

        let second = SessionStore(store: secure)
        #expect(await second.restore())
        #expect(await second.accessToken == "a")

        await second.clear()
        let third = SessionStore(store: secure)
        #expect(await !third.restore())
    }
}
