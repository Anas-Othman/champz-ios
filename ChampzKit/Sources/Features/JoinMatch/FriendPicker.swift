import Observation
import SwiftUI

/// "Add Players": search the transfer market and pick up to `maxSelectable` friends.
@MainActor
@Observable
public final class FriendPickerViewModel {
    public let maxSelectable: Int
    public var query = ""
    public private(set) var state: Loadable<[FriendCandidate]> = .idle
    public private(set) var selected: [FriendCandidate]

    private let content: any ContentRepository
    private let toasts: ToastCenter

    public init(maxSelectable: Int, selected: [FriendCandidate], content: any ContentRepository, toasts: ToastCenter) {
        self.maxSelectable = maxSelectable
        self.selected = selected
        self.content = content
        self.toasts = toasts
    }

    /// Called from `.task(id: query)`: SwiftUI cancels the previous search when the query changes.
    public func search() async {
        if case .loaded = state {} else {
            state = .loading
        }
        do {
            try await Task.sleep(for: .milliseconds(350)) // debounce, as the current app
            let results = try await content.searchPlayers(query.trimmingCharacters(in: .whitespaces))
            state = .loaded(results)
        } catch is CancellationError {
            return
        } catch let error as AppError {
            state = .failed(error)
        } catch {
            return
        }
    }

    public func isSelected(_ player: FriendCandidate) -> Bool {
        selected.contains { $0.id == player.id }
    }

    public func toggle(_ player: FriendCandidate) {
        if let index = selected.firstIndex(where: { $0.id == player.id }) {
            selected.remove(at: index)
        } else if selected.count < maxSelectable {
            selected.append(player)
        } else {
            toasts.show(Toast(.info, text: L10n.Join.maxPlayers(maxSelectable)))
        }
    }
}

struct FriendPickerSheet: View {
    @State var viewModel: FriendPickerViewModel
    let onDone: ([FriendCandidate]) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            LoadableView(
                viewModel.state,
                isEmpty: \.isEmpty,
                emptyTitle: L10n.TransferMarket.noPlayersFound,
                retry: { await viewModel.search() }
            ) { players in
                List(players) { player in
                    Button { viewModel.toggle(player) } label: { row(player) }
                        .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }
            .searchable(text: $viewModel.query, prompt: Text(L10n.Team.searchForFriend))
            .task(id: viewModel.query) { await viewModel.search() }
            .navigationTitle(Text(L10n.Court.addPlayers))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(.close) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        onDone(viewModel.selected)
                        dismiss()
                    } label: {
                        Text(verbatim: viewModel.selected.isEmpty ? String(localized: L10n.TransferMarket.select) : L10n
                            .Join.selectCount(viewModel.selected.count))
                    }
                }
            }
        }
    }

    private func row(_ player: FriendCandidate) -> some View {
        HStack(spacing: Spacing.m) {
            AvatarView(url: player.avatarUrl, name: player.fullName, size: 40)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(verbatim: player.fullName).font(AppFont.bodyEmphasis).foregroundStyle(.ds.textPrimary)
                if let position = player.position?.name, !position.isEmpty {
                    Text(verbatim: position).font(AppFont.caption).foregroundStyle(.ds.textSecondary)
                }
            }
            Spacer()
            Image(viewModel.isSelected(player) ? .checkCircle : .circle)
                .foregroundStyle(viewModel.isSelected(player) ? Color.ds.brandPrimary : Color.ds.controlUnselected)
        }
        .contentShape(Rectangle())
    }
}
