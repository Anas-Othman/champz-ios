import Foundation

/// The state of anything a screen loads asynchronously. `LoadableView` in DesignSystem
/// renders every case the same way across the app.
public enum Loadable<Value: Sendable>: Sendable {
    case idle
    case loading
    case loaded(Value)
    case failed(AppError)

    /// Runs `work` and wraps the outcome. Cancellation becomes `.failed(.cancelled)`.
    public init(_ work: () async throws(AppError) -> Value) async {
        do {
            self = try await .loaded(work())
        } catch {
            self = Task.isCancelled ? .failed(.cancelled) : .failed(error)
        }
    }

    public var value: Value? {
        if case let .loaded(value) = self {
            return value
        }
        return nil
    }

    public var error: AppError? {
        if case let .failed(error) = self {
            return error
        }
        return nil
    }

    public var isLoading: Bool {
        if case .loading = self {
            return true
        }
        return false
    }

    public func map<T: Sendable>(_ transform: (Value) -> T) -> Loadable<T> {
        switch self {
        case .idle: .idle
        case .loading: .loading
        case let .loaded(value): .loaded(transform(value))
        case let .failed(error): .failed(error)
        }
    }
}

extension Loadable: Equatable where Value: Equatable {}
