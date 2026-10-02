import Foundation

/// Something changed that other screens may be showing. Repositories post these after
/// a mutation; screens that display the data listen and reload (guide, section 8).
public enum AppEvent: Sendable, Equatable {
    case walletChanged
    case matchJoined(MatchID)
    case matchLeft(MatchID)
    case bookingChanged(BookingID)
    case tournamentJoined(TournamentID)
    case teamChanged(TeamID)
    case profileChanged
    case notificationsChanged
}

/// A broadcast stream with any number of listeners.
public actor AppEvents {
    private var continuations: [UUID: AsyncStream<AppEvent>.Continuation] = [:]

    public init() {}

    public func post(_ event: AppEvent) {
        for continuation in continuations.values {
            continuation.yield(event)
        }
    }

    /// Each call returns an independent stream; it ends when the consumer's task is cancelled.
    public func stream() -> AsyncStream<AppEvent> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<AppEvent>.makeStream()
        continuations[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { await self?.remove(id) }
        }
        return stream
    }

    private func remove(_ id: UUID) {
        continuations[id] = nil
    }
}
