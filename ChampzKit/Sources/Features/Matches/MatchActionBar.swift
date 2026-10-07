import SwiftUI

/// Sticky bottom bar: spots counter (hidden when leaving) + the primary action.
struct MatchActionBar: View {
    let match: Match
    let isWorking: Bool
    let onSpots: () -> Void
    let onPrimary: () -> Void

    private var isLeaving: Bool {
        match.primaryAction == .leave || match.primaryAction == .leaveWaitingList
    }

    var body: some View {
        HStack(spacing: Spacing.s) {
            if !isLeaving {
                Button(action: onSpots) {
                    VStack(spacing: 0) {
                        Text(verbatim: "\(match.joinedPlayerCount)/\(match.totalPlayers)")
                            .font(AppFont.buttonLarge)
                            .foregroundStyle(.ds.textPrimary)
                        Text(L10n.FriendlyMatch.spots).font(AppFont.captionSmall).foregroundStyle(.ds.textSecondary)
                    }
                    .padding(.horizontal, Spacing.l)
                    .padding(.vertical, 5.5)
                    .overlay(RoundedRectangle(cornerRadius: Radius.m, style: .continuous).strokeBorder(
                        Color.ds.accentSoft,
                        lineWidth: 3
                    ))
                }
                .buttonStyle(.plain)
            }
            AppButton(title, style: isLeaving ? .destructiveOutline : .primary, isLoading: isWorking, action: onPrimary)
                .disabled(match.primaryAction == .full)
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.top, Spacing.l)
        .padding(.bottom, 34)
        .background(isLeaving ? Color.clear : Color.ds.surface)
    }

    private var title: LocalizedStringResource {
        switch match.primaryAction {
        case .leave: L10n.Team.leaveMatch
        case .leaveWaitingList: L10n.Matches.leaveWaitingList
        case .joinWaitingList: L10n.Tournament.joinWaitingList
        case .full: L10n.Tournament.slotFull
        case .join:
            match.effectivePrice.isZero ? L10n.FriendlyMatch
                .joinFree : LocalizedStringResource(stringLiteral: L10n.Matches.joinFor(match.effectivePrice.compact))
        }
    }
}

/// 64pt pink circle with the chat icon.
struct ChatButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(.brandChat)
                .resizable().scaledToFit().frame(width: 26, height: 26)
                .foregroundStyle(.ds.onBrand)
                .frame(width: 64, height: 64)
                .background(Color.ds.accent, in: Circle())
        }
        .accessibilityLabel(Text(L10n.Matches.chat))
    }
}

/// Loading placeholder shaped like the page: hero, title lines, info card, text block.
struct MatchDetailSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            Rectangle().fill(Color.ds.skeleton).frame(height: 280)
            VStack(alignment: .leading, spacing: Spacing.m) {
                bar(width: 220, height: 28)
                bar(width: 260, height: 20)
                bar(width: 180, height: 20)
                bar(height: 84).padding(.top, Spacing.s)
                bar(height: 120).padding(.top, Spacing.l)
            }
            .padding(.horizontal, Spacing.gutter)
            Spacer()
        }
        .ignoresSafeArea(edges: .top)
        .shimmering()
        .accessibilityHidden(true)
    }

    private func bar(width: CGFloat? = nil, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
            .fill(Color.ds.skeleton)
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
    }
}
