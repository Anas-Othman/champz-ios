import Core
import Localization
import SwiftUI

/// Renders a `Loadable<T>` the same way everywhere: skeleton while loading, content
/// when loaded, an empty state when `isEmpty`, and an error state with retry.
public struct LoadableView<Value: Sendable, Content: View, Placeholder: View>: View {
    private let state: Loadable<Value>
    private let isEmpty: (Value) -> Bool
    private let emptyTitle: LocalizedStringResource
    private let retry: (() async -> Void)?
    private let placeholder: () -> Placeholder
    private let content: (Value) -> Content

    /// - Parameters:
    ///   - placeholder: the skeleton layout shown while loading (defaults to a generic list skeleton).
    ///   - retry: shown on retryable errors.
    public init(
        _ state: Loadable<Value>,
        isEmpty: @escaping (Value) -> Bool = { _ in false },
        emptyTitle: LocalizedStringResource = L10n.Errors.emptyTitle,
        retry: (() async -> Void)? = nil,
        @ViewBuilder placeholder: @escaping () -> Placeholder = { ListSkeleton() },
        @ViewBuilder content: @escaping (Value) -> Content
    ) {
        self.state = state
        self.isEmpty = isEmpty
        self.emptyTitle = emptyTitle
        self.retry = retry
        self.placeholder = placeholder
        self.content = content
    }

    public var body: some View {
        switch state {
        case .idle, .loading:
            placeholder()
                .transition(.opacity)
        case let .loaded(value):
            if isEmpty(value) {
                EmptyStateView(title: emptyTitle)
            } else {
                content(value)
            }
        case let .failed(error):
            ErrorStateView(error: error, retry: retry)
        }
    }
}

public struct EmptyStateView: View {
    private let title: LocalizedStringResource
    private let message: LocalizedStringResource?
    private let icon: AppIcon

    public init(title: LocalizedStringResource, message: LocalizedStringResource? = nil, icon: AppIcon = .empty) {
        self.title = title
        self.message = message
        self.icon = icon
    }

    public var body: some View {
        VStack(spacing: Spacing.m) {
            Image(icon)
                .font(AppFont.stateIcon)
                .foregroundStyle(.ds.textTertiary)
            Text(title)
                .font(AppFont.headline)
                .foregroundStyle(.ds.textPrimary)
            if let message {
                Text(message)
                    .font(AppFont.body)
                    .foregroundStyle(.ds.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(Spacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

public struct ErrorStateView: View {
    private let error: AppError
    private let retry: (() async -> Void)?
    @State private var isRetrying = false

    public init(error: AppError, retry: (() async -> Void)? = nil) {
        self.error = error
        self.retry = retry
    }

    public var body: some View {
        VStack(spacing: Spacing.m) {
            Image(error.icon)
                .font(AppFont.stateIcon)
                .foregroundStyle(.ds.statusError)
            Text(error.title)
                .font(AppFont.headline)
                .foregroundStyle(.ds.textPrimary)
            Text(error.message)
                .font(AppFont.body)
                .foregroundStyle(.ds.textSecondary)
                .multilineTextAlignment(.center)
            if let retry, error.isRetryable {
                AppButton(L10n.Errors.retry, style: .secondary, isLoading: isRetrying) {
                    Task {
                        isRetrying = true
                        await retry()
                        isRetrying = false
                    }
                }
                .padding(.top, Spacing.s)
            }
        }
        .padding(Spacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// A generic loading placeholder: a few redacted rows.
public struct ListSkeleton: View {
    private let rows: Int

    public init(rows: Int = 4) {
        self.rows = rows
    }

    public var body: some View {
        VStack(spacing: Spacing.m) {
            ForEach(0 ..< rows, id: \.self) { _ in
                RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                    .fill(Color.ds.skeleton)
                    .frame(height: 88)
            }
        }
        .padding(Spacing.gutter)
        .shimmering()
        .accessibilityHidden(true)
    }
}

public extension View {
    /// A gentle opacity pulse for skeletons.
    func shimmering() -> some View {
        modifier(ShimmerModifier())
    }
}

private struct ShimmerModifier: ViewModifier {
    @State private var pulse = false

    func body(content: Content) -> some View {
        content
            .opacity(pulse ? 0.55 : 1)
            .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
            .onAppear { pulse = true }
    }
}

#Preview("States") {
    VStack {
        ErrorStateView(error: .offline) {}
        EmptyStateView(title: L10n.Errors.emptyTitle)
        ListSkeleton(rows: 2)
    }
}
