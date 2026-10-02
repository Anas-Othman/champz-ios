import Domain
import Foundation
import Testing
@testable import Navigation

@MainActor
struct AppRouterTests {
    @Test func pushPopAndRootPerTab() {
        let router = AppRouter()
        router.push(.matchDetail(MatchID("1")))
        router.push(.chat(MatchID("1")))
        #expect(router.paths[.home] == [.matchDetail(MatchID("1")), .chat(MatchID("1"))])

        router.pop()
        #expect(router.paths[.home] == [.matchDetail(MatchID("1"))])

        router.push(.walletHistory, on: .myStats)
        #expect(router.selectedTab == .myStats)
        router.popToRoot()
        #expect(router.paths[.myStats] == [])
        #expect(router.paths[.home] == [.matchDetail(MatchID("1"))])
    }

    @Test func reselectingTabPopsToRoot() {
        let router = AppRouter()
        router.push(.matchDetail(MatchID("1")))
        router.select(.home)
        #expect(router.paths[.home] == [])
        router.select(.transferMarket)
        #expect(router.selectedTab == .transferMarket)
    }

    @Test func deepLinkWhileSignedOutIsReplayedLater() {
        let router = AppRouter()
        router.open(.match(MatchID("9")), isSignedIn: false)
        #expect(router.paths[.home, default: []].isEmpty)
        #expect(router.pendingDeepLink == .match(MatchID("9")))

        router.replayPendingDeepLink()
        #expect(router.paths[.home] == [.matchDetail(MatchID("9"))])
        #expect(router.pendingDeepLink == nil)
    }
}

struct DeepLinkParserTests {
    private func url(_ string: String) -> URL {
        // swiftlint:disable:next force_unwrapping
        URL(string: string)!
    }

    @Test func paymentCallback() {
        #expect(DeepLinkParser.parse(url("champz://payment/callback?status=paid")) == .paymentCallback(.paid))
        #expect(DeepLinkParser.parse(url("champz://payment/callback?status=failed")) == .paymentCallback(.failed))
        #expect(DeepLinkParser.parse(url("champz://payment/callback")) == .paymentCallback(.failed))
    }

    @Test func universalLinks() {
        #expect(DeepLinkParser.parse(url("https://champz.me/match/12")) == .match(MatchID("12")))
        #expect(DeepLinkParser.parse(url("https://staging.champz.me/tournaments/3")) == .tournament(TournamentID("3")))
        #expect(DeepLinkParser.parse(url("https://champz.me/wallet")) == .wallet)
        #expect(DeepLinkParser.parse(url("https://example.com/match/12")) == nil)
        #expect(DeepLinkParser.parse(url("https://champz.me/match/01J9ABCDEF")) == .match(MatchID("01J9ABCDEF")))
        #expect(DeepLinkParser.parse(url("https://champz.me/match/")) == nil)
    }

    @Test func pushPayloads() {
        #expect(DeepLinkParser.parse(notification: ["type": "match", "id": "5"]) == .match(MatchID("5")))
        #expect(DeepLinkParser.parse(notification: ["type": "wallet"]) == .wallet)
        #expect(DeepLinkParser.parse(notification: ["type": "mystery", "id": "5"]) == nil)
    }
}
