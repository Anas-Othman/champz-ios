import SwiftUI

/// "NOTIFICATIONS": Mark all as read in the bar, then my feed. Unread rows have a dot and a
/// tinted background; open court invites carry Accept / Decline.
public struct NotificationsView: View {
    @State var viewModel: NotificationsViewModel

    public init(viewModel: NotificationsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        LoadableView(
            viewModel.state,
            isEmpty: \.isEmpty,
            emptyTitle: L10n.Notifications.noNotifications,
            retry: { await viewModel.reload() }
        ) { items in
            ScrollView {
                LazyVStack(spacing: Spacing.s) {
                    ForEach(items) { item in
                        NotificationRow(
                            item: item,
                            showsInviteButtons: viewModel.showsInviteButtons(item),
                            onOpen: { viewModel.open(item) },
                            onDecline: { viewModel.askToDecline(item) }
                        )
                        .task { await viewModel.loadMoreIfNeeded(after: item) }
                    }
                    if viewModel.isLoadingMore {
                        ProgressView().padding(Spacing.l)
                    }
                }
                .padding(Spacing.gutter)
            }
            .refreshable { await viewModel.reload() }
        }
        .background(Color.ds.backgroundMuted)
        .navigationTitle(Text(L10n.Notifications.notifications))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { Task { await viewModel.markAllRead() } } label: { Text(L10n.Notifications.markAllAsRead) }
                    .disabled(!viewModel.hasUnread)
            }
        }
        .confirmationDialog(
            Text(L10n.Notifications.declineTitle),
            isPresented: Binding(
                get: { viewModel.inviteToDecline != nil },
                set: {
                    if !$0 {
                        viewModel.inviteToDecline = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button(role: .destructive) { Task { await viewModel.confirmDecline() } } label: {
                Text(L10n.Notifications.decline)
            }
        } message: {
            Text(L10n.Notifications.declineMessage)
        }
        .task { await viewModel.load() }
    }
}

/// Icon by kind, title and message, time ago, unread dot; invite buttons when it waits for me.
struct NotificationRow: View {
    let item: AppNotification
    let showsInviteButtons: Bool
    let onOpen: () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Button(action: onOpen) {
                HStack(alignment: .top, spacing: Spacing.m) {
                    Image(item.notifyType.icon)
                        .font(.body)
                        .foregroundStyle(.ds.brandPrimary)
                        .frame(width: 44, height: 44)
                        .background(Color.ds.brandAccentSoft, in: Circle())
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        if !item.title.isEmpty {
                            Text(verbatim: item.title).font(AppFont.bodyEmphasis.weight(.bold))
                                .foregroundStyle(.ds.textPrimary)
                        }
                        Text(verbatim: item.message).font(AppFont.body).foregroundStyle(.ds.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        if let date = item.date {
                            // "9 hours ago", "yesterday", in the phone's language.
                            Text(verbatim: date.formatted(.relative(presentation: .named, unitsStyle: .wide)))
                                .font(AppFont.caption)
                                .foregroundStyle(.ds.textSecondary)
                        }
                    }
                    Spacer(minLength: 0)
                    if !item.isRead {
                        Circle().fill(Color.ds.brandPrimary).frame(width: 8, height: 8).padding(.top, Spacing.xs)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if showsInviteButtons {
                HStack(spacing: Spacing.s) {
                    AppButton(L10n.Notifications.decline, style: .secondary, action: onDecline)
                    AppButton(L10n.Notifications.accept, style: .primary, action: onOpen)
                }
            }
        }
        .padding(Spacing.l)
        .background(
            item.isRead ? Color.ds.surface : Color.ds.brandAccentSoft.opacity(0.35),
            in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous)
        )
        .accessibilityElement(children: .contain)
    }
}

extension AppNotification.Kind {
    var icon: AppIcon {
        switch self {
        case .courtBooking: .calendar
        case .transferTournament, .transferFriendly: .transferMarket
        case .friendlyJoin: .players
        case .match, .unknown: .football
        }
    }
}
