import ChampzKit
import SwiftUI

/// Switches the whole UI on the auth phase.
struct RootView: View {
    let container: AppContainer

    var body: some View {
        Group {
            switch container.authState.phase {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.ds.background)
            case .signedOut:
                AuthFlowView(auth: container.auth, toasts: container.toasts, onSignedIn: container.signedIn)
            case .needsProfile:
                ProfileSetupPlaceholderView(container: container)
            case .signedIn:
                MainTabView(container: container)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: container.authState.phase)
    }
}

/// The tab bar: one `NavigationStack` per tab, all driven by `AppRouter`.
struct MainTabView: View {
    let container: AppContainer

    var body: some View {
        @Bindable var router = container.router
        TabView(selection: tabSelection) {
            ForEach(AppTab.allCases) { tab in
                NavigationStack(path: router.path(for: tab)) {
                    tabRoot(tab)
                        .navigationDestination(for: AppRoute.self) { route in
                            AppDestinations.view(for: route, container: container)
                        }
                }
                .tabItem {
                    Label {
                        Text(tab.title)
                    } icon: {
                        Image(tab.icon)
                    }
                }
                .tag(tab)
            }
        }
        .tint(Color.ds.brandPrimary)
        .sheet(item: sheetBinding(fullScreen: false)) { sheet in
            AppDestinations.view(for: sheet, container: container)
        }
        .fullScreenCover(item: sheetBinding(fullScreen: true)) { sheet in
            AppDestinations.view(for: sheet, container: container)
        }
    }

    /// Re-selecting the current tab pops it to root.
    private var tabSelection: Binding<AppTab> {
        Binding(
            get: { container.router.selectedTab },
            set: { container.router.select($0) }
        )
    }

    private func sheetBinding(fullScreen: Bool) -> Binding<AppSheet?> {
        Binding(
            get: {
                guard let sheet = container.router.sheet, sheet.isFullScreen == fullScreen else { return nil }
                return sheet
            },
            set: {
                if $0 == nil {
                    container.router.dismissSheet()
                }
            }
        )
    }

    @ViewBuilder
    private func tabRoot(_ tab: AppTab) -> some View {
        switch tab {
        case .home: HomeView(viewModel: HomeViewModel(
                matches: container.matches,
                courts: container.courts,
                router: container.router,
                toasts: container.toasts
            ))
        case .transferMarket: TransferMarketView(viewModel: container.makeTransferMarket())
        case .myStats: MyStatsView(viewModel: container.makeMyStats())
        }
    }
}

/// Stands in for the profile-setup flow (name, age, nationality, position) until the Profile feature lands.
struct ProfileSetupPlaceholderView: View {
    let container: AppContainer

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()
            EmptyStateView(
                title: L10n.SignUp.completeProfileFirst,
                message: L10n.Auth.profileSetupPlaceholder,
                icon: .edit
            )
            Spacer()
            AppButton(L10n.Common.continueKey, style: .primary) {
                container.authState.transition(to: .signedIn)
            }
        }
        .padding(Spacing.gutter)
        .background(Color.ds.background)
    }
}

extension AppTab {
    var title: LocalizedStringResource {
        switch self {
        case .home: L10n.Tabs.home
        case .transferMarket: L10n.Tabs.transferMarket
        case .myStats: L10n.Tabs.myStats
        }
    }

    var icon: AppIcon {
        switch self {
        case .home: .home
        case .transferMarket: .transferMarket
        case .myStats: .stats
        }
    }
}
