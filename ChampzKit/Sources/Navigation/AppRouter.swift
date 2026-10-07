import Foundation
import Observation
import SwiftUI

/// The single owner of navigation state: one path per tab, one presented sheet, the
/// selected tab. View models call `push`/`present`; views bind to `path(for:)`.
@MainActor
@Observable
public final class AppRouter {
    public var selectedTab: AppTab = .home
    public var paths: [AppTab: [AppRoute]] = [:]
    public var sheet: AppSheet?
    /// A deep link that arrived while signed out, replayed after login.
    public private(set) var pendingDeepLink: DeepLink?

    public init() {}

    public func push(_ route: AppRoute, on tab: AppTab? = nil) {
        let target = tab ?? selectedTab
        if tab != nil {
            selectedTab = target
        }
        paths[target, default: []].append(route)
        Log.navigation
            .debug("push \(String(describing: route), privacy: .public) on \(target.rawValue, privacy: .public)")
    }

    /// Back from a screen that hides the navigation bar.
    public func goBack() {
        pop()
    }

    public func pop(on tab: AppTab? = nil) {
        let target = tab ?? selectedTab
        guard !(paths[target]?.isEmpty ?? true) else { return }
        paths[target]?.removeLast()
    }

    /// Pops back to the most recent screen matching `route` (e.g. the match after joining).
    public func popTo(_ route: AppRoute) {
        guard let index = paths[selectedTab]?.lastIndex(of: route) else { return }
        paths[selectedTab]?.removeSubrange((index + 1)...)
    }

    public func popToRoot(on tab: AppTab? = nil) {
        paths[tab ?? selectedTab] = []
    }

    public func present(_ sheet: AppSheet) {
        self.sheet = sheet
    }

    public func dismissSheet() {
        sheet = nil
    }

    /// Tapping the already-selected tab pops it to root, as users expect on iOS.
    public func select(_ tab: AppTab) {
        if tab == selectedTab {
            popToRoot(on: tab)
        } else {
            selectedTab = tab
        }
    }

    /// SwiftUI binding for a tab's `NavigationStack`.
    public func path(for tab: AppTab) -> Binding<[AppRoute]> {
        Binding(
            get: { self.paths[tab, default: []] },
            set: { self.paths[tab] = $0 }
        )
    }

    // MARK: - Deep links

    /// Applies a deep link now, or stores it until the user is signed in.
    public func open(_ link: DeepLink, isSignedIn: Bool) {
        guard isSignedIn else {
            pendingDeepLink = link
            return
        }
        pendingDeepLink = nil
        sheet = nil
        switch link {
        case let .match(id): push(.matchDetail(id), on: .home)
        case let .tournament(id): push(.tournamentDetail(id), on: .home)
        case let .booking(id): push(.bookingDetail(id), on: .home)
        case let .venue(id): push(.venueDetail(id), on: .home)
        case let .team(id): push(.teamDetail(id), on: .home)
        case .wallet: push(.walletHistory, on: .home)
        case .notifications: push(.notifications, on: .home)
        case let .push(route): push(route, on: .home)
        case .paymentCallback:
            // Handled by the checkout flow while it is presented; nothing to navigate to here.
            break
        }
    }

    public func replayPendingDeepLink() {
        guard let link = pendingDeepLink else { return }
        open(link, isSignedIn: true)
    }
}
