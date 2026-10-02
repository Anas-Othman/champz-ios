import DesignSystem
import Localization
import Navigation
import SwiftUI

/// Route → view. The one place that knows which feature renders which destination.
/// Each feature module will expose a `Destinations` entry point; until then, placeholders.
enum AppDestinations {
    @MainActor
    @ViewBuilder
    static func view(for route: AppRoute, container: AppContainer) -> some View {
        switch route {
        case .settings:
            #if DEBUG
                DesignSystemCatalogView()
            #else
                PlaceholderScreen(title: L10n.Settings.settings, icon: .settings)
            #endif
        case .notifications:
            PlaceholderScreen(title: L10n.Notifications.notifications, icon: .notifications)
        case .walletHistory:
            PlaceholderScreen(title: L10n.Payment.myWallet, icon: .wallet)
        case .matchDetail, .venueDetail, .bookingDetail, .tournamentDetail, .teamDetail, .playerProfile, .chat:
            PlaceholderScreen(title: L10n.Common.pleaseWait, icon: .football)
        }
    }

    @MainActor
    @ViewBuilder
    static func view(for sheet: AppSheet, container: AppContainer) -> some View {
        switch sheet {
        case .checkout:
            PlaceholderScreen(title: L10n.Payment.payment, icon: .wallet)
        case .editProfile:
            PlaceholderScreen(title: L10n.Profile.editProfile, icon: .edit)
        case .matchFilters:
            PlaceholderScreen(title: L10n.Common.selectOptions, icon: .filter)
        }
    }
}

/// Stand-in for screens not yet ported. Lets navigation and deep links be exercised end to end.
struct PlaceholderScreen: View {
    let title: LocalizedStringResource
    let icon: AppIcon

    var body: some View {
        EmptyStateView(title: title, icon: icon)
            .navigationTitle(Text(title))
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.ds.background)
    }
}
