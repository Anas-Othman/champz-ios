import Foundation
import Observation

/// "Payments" (payments_screen.dart): my balance, Top up, and my transactions, newest first.
@MainActor
@Observable
public final class WalletViewModel {
    public struct Content: Hashable, Sendable {
        public var balance: Money
        public var entries: [LedgerEntry]
    }

    public private(set) var state: Loadable<Content> = .idle
    public private(set) var isLoadingMore = false

    /// Empty when there is no next page.
    private var nextCursor = ""
    private let wallet: any WalletRepository
    private let payments: any PaymentRepository
    private let router: AppRouter
    private let toasts: ToastCenter

    public init(wallet: any WalletRepository, payments: any PaymentRepository, router: AppRouter, toasts: ToastCenter) {
        self.wallet = wallet
        self.payments = payments
        self.router = router
        self.toasts = toasts
    }

    public func load() async {
        guard case .idle = state else { return }
        state = .loading
        await reload()
    }

    /// Balance and the first page together. Pull to refresh keeps the list on screen meanwhile.
    public func reload() async {
        do {
            async let balance = payments.wallet()
            async let page = wallet.transactions(cursor: nil)
            let (current, first) = try await (balance, page)
            nextCursor = first.nextCursor
            state = .loaded(Content(balance: current.money, entries: first.items))
        } catch {
            let error = error as? AppError ?? .unknown
            if case .loaded = state {
                toasts.show(error)
            } else {
                state = .failed(error)
            }
        }
    }

    /// Call from each row as it appears; only the last one loads the next page, with the cursor.
    /// (The current app re-fetched the first page every time and showed it again.)
    public func loadMoreIfNeeded(after entry: LedgerEntry) async {
        guard !nextCursor.isEmpty, !isLoadingMore, case var .loaded(content) = state,
              content.entries.last?.id == entry.id else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await wallet.transactions(cursor: nextCursor)
            nextCursor = page.nextCursor
            content.entries += page.items
            state = .loaded(content)
        } catch {
            toasts.show(error)
        }
    }

    public func topUp() {
        router.push(.topUp)
    }
}
