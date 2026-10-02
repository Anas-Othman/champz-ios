import Core
import Observation
import SwiftUI

/// Non-blocking feedback for actions (joined, saved, payment cancelled). One `ToastCenter`
/// lives in the environment; the root view attaches `.toastHost()`.
public struct Toast: Identifiable, Equatable, Sendable {
    public enum Kind: Sendable { case success, error, info }

    public let id = UUID()
    public let kind: Kind
    public let message: LocalizedStringResource

    public init(_ kind: Kind, _ message: LocalizedStringResource) {
        self.kind = kind
        self.message = message
    }

    public static func == (lhs: Toast, rhs: Toast) -> Bool {
        lhs.id == rhs.id
    }
}

@MainActor
@Observable
public final class ToastCenter {
    public private(set) var current: Toast?
    private var dismissTask: Task<Void, Never>?

    public init() {}

    public func show(_ toast: Toast, for duration: Duration = .seconds(3)) {
        dismissTask?.cancel()
        withAnimation(.spring(duration: 0.3)) { current = toast }
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.2)) { self?.current = nil }
        }
    }

    public func show(_ error: AppError) {
        show(Toast(.error, error.message))
    }

    public func dismiss() {
        dismissTask?.cancel()
        withAnimation { current = nil }
    }
}

public extension View {
    func toastHost(_ center: ToastCenter) -> some View {
        modifier(ToastHostModifier(center: center))
    }
}

private struct ToastHostModifier: ViewModifier {
    let center: ToastCenter

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let toast = center.current {
                ToastView(toast: toast)
                    .padding(.horizontal, Spacing.gutter)
                    .padding(.top, Spacing.s)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onTapGesture { center.dismiss() }
            }
        }
    }
}

private struct ToastView: View {
    let toast: Toast

    var body: some View {
        HStack(spacing: Spacing.m) {
            Image(icon).foregroundStyle(tint)
            Text(toast.message)
                .font(AppFont.body)
                .foregroundStyle(.ds.textPrimary)
                .lineLimit(3)
            Spacer(minLength: 0)
        }
        .padding(Spacing.l)
        .background(Color.ds.surface, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                .strokeBorder(tint.opacity(0.4), lineWidth: 1)
        }
        .shadow(color: Color.ds.textPrimary.opacity(0.08), radius: 12, y: 4)
        .accessibilityElement(children: .combine)
    }

    private var icon: AppIcon {
        switch toast.kind {
        case .success: .checkCircle
        case .error: .error
        case .info: .info
        }
    }

    private var tint: Color {
        switch toast.kind {
        case .success: .ds.statusSuccess
        case .error: .ds.statusError
        case .info: .ds.statusInfo
        }
    }
}
