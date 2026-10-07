import SwiftUI

/// Match chat: the match in the title bar (tap for the team sheet), messages with mine on the
/// right in purple, older ones loaded on reaching the top, and the message box at the bottom.
public struct ChatView: View {
    @State var viewModel: ChatViewModel
    @FocusState private var isTyping: Bool

    public init(viewModel: ChatViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        content
            .background(Color.ds.backgroundMuted)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) { header }
            }
            .task { await viewModel.run() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .loading:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .unavailable:
            EmptyStateView(title: L10n.Chat.unavailable, icon: .chat)
        case let .failed(message):
            VStack(spacing: Spacing.l) {
                Text(verbatim: message).font(AppFont.bodyEmphasis).foregroundStyle(.ds.textSecondary)
                AppButton(L10n.Chat.retry, style: .secondary) { Task { await viewModel.run() } }
                    .frame(width: 160)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .ready:
            messages.safeAreaInset(edge: .bottom) { inputBar }
        }
    }

    /// Match picture, name and "+N Players"; opens the team sheet.
    private var header: some View {
        Button(action: viewModel.openTeams) {
            HStack(spacing: Spacing.s) {
                RemoteImage(url: viewModel.match?.tournamentImage ?? "", cornerRadius: Radius.s) {
                    Color.ds.separator
                }
                .frame(width: 32, height: 32)
                VStack(alignment: .leading, spacing: 0) {
                    Text(verbatim: viewModel.match?.title ?? String(localized: L10n.Chat.title))
                        .font(AppFont.bodyEmphasis.weight(.bold))
                        .foregroundStyle(.ds.textPrimary)
                        .lineLimit(1)
                    if let count = viewModel.match?.joinedPlayerCount, count > 0 {
                        Text(verbatim: L10n.Chat.playerCount(count)).font(AppFont.captionSmall)
                            .foregroundStyle(.ds.textSecondary)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var messages: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: Spacing.m) {
                    if viewModel.messages.isEmpty {
                        Text(L10n.Chat.empty)
                            .font(AppFont.detailBody)
                            .foregroundStyle(.ds.textTertiary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 120)
                    } else if viewModel.hasOlder {
                        ProgressView()
                            .padding(Spacing.s)
                            .task { await viewModel.loadOlder() } // reached the top
                    }
                    ForEach(viewModel.messages) { message in
                        MessageBubble(message: message, isMine: viewModel.isMine(message)).id(message.id)
                    }
                }
                .padding(Spacing.gutter)
            }
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.messages.last?.id) { _, last in
                guard let last else { return }
                withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(last, anchor: .bottom) }
            }
        }
    }

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: Spacing.s) {
            TextField(text: $viewModel.draft, axis: .vertical) {
                Text(L10n.Chat.placeholder).foregroundStyle(.ds.textTertiary)
            }
            .font(AppFont.body)
            .lineLimit(1 ... 5)
            .focused($isTyping)
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.m)
            .background(Color.ds.surface, in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.l, style: .continuous).strokeBorder(Color.ds.separator))
            .onChange(of: viewModel.draft) { _, text in
                if text.count > ChatDraft.maxLength {
                    viewModel.draft = String(text.prefix(ChatDraft.maxLength))
                }
            }
            Button { Task { await viewModel.send() } } label: {
                Image(.send)
                    .font(.body.weight(.bold))
                    .foregroundStyle(.ds.onBrand)
                    .frame(width: 44, height: 44)
                    .background(viewModel.canSend ? Color.ds.brandPrimary : Color.ds.textTertiary, in: Circle())
            }
            .disabled(!viewModel.canSend)
            .accessibilityLabel(Text(L10n.Chat.send))
        }
        .padding(.horizontal, Spacing.gutter)
        .padding(.vertical, Spacing.s)
        .background(Color.ds.backgroundMuted)
    }
}

/// One message: others on the left with avatar and name, mine on the right in purple; time below.
struct MessageBubble: View {
    let message: ChatMessage
    let isMine: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: Spacing.s) {
            if isMine {
                Spacer(minLength: 48)
            } else {
                AvatarView(url: message.avatar, name: message.senderName, size: 32)
            }
            VStack(alignment: isMine ? .trailing : .leading, spacing: Spacing.xxs) {
                if !isMine, !message.senderName.isEmpty {
                    Text(verbatim: message.senderName).font(AppFont.captionSmall.weight(.bold))
                        .foregroundStyle(.ds.brandPrimary)
                }
                Text(verbatim: message.text)
                    .font(AppFont.body)
                    .foregroundStyle(isMine ? Color.ds.onBrand : Color.ds.textPrimary)
                    .padding(.horizontal, Spacing.m)
                    .padding(.vertical, Spacing.s + 2)
                    .background(
                        isMine ? Color.ds.brandPrimary : Color.ds.surface,
                        in: UnevenRoundedRectangle(
                            topLeadingRadius: 16,
                            bottomLeadingRadius: isMine ? 16 : 4,
                            bottomTrailingRadius: isMine ? 4 : 16,
                            topTrailingRadius: 16,
                            style: .continuous
                        )
                    )
                Text(verbatim: message.timeText).font(AppFont.captionSmall).foregroundStyle(.ds.textTertiary)
            }
            if !isMine {
                Spacer(minLength: 48)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
