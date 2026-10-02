import Foundation

/// The bottom tabs, mirroring the current app's navigation: Transfer Market · Home · My Stats.
public enum AppTab: String, CaseIterable, Hashable, Sendable, Identifiable {
    case transferMarket
    case home
    case myStats

    public var id: String {
        rawValue
    }
}
