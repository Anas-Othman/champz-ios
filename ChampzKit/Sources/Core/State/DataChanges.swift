import Observation

/// A tiny "something changed on the server" signal for data shown on several screens.
/// Whoever changes it bumps the version; screens showing it refresh when the version moves.
/// (Appearance callbacks alone are not enough: a screen below in the stack may never
/// reappear in the way `onAppear` expects, and Home / lists are not "below" at all.)
@MainActor
@Observable
public final class DataChanges {
    /// Bumped after joining, leaving, or waiting-list changes on any match.
    public private(set) var matchesVersion = 0

    public init() {}

    /// Bumped when notifications are read or answered, so bells refresh their badge.
    public private(set) var notificationsVersion = 0

    public func notificationsChanged() {
        notificationsVersion += 1
    }

    /// Bumped after money lands in or leaves the wallet outside a join (a top-up).
    public private(set) var walletVersion = 0

    public func walletChanged() {
        walletVersion += 1
    }

    /// Bumped after the player edits their profile (name, photo…).
    public private(set) var profileVersion = 0

    public func profileChanged() {
        profileVersion += 1
    }

    /// Bumped after joining or leaving a tournament.
    public private(set) var tournamentsVersion = 0

    public func tournamentsChanged() {
        tournamentsVersion += 1
    }

    public func matchesChanged() {
        matchesVersion += 1
    }
}
