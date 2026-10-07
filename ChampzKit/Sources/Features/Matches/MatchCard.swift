import SwiftUI

/// The match tile used by the Home "Upcoming matches" row and the Find-a-match list.
/// Image with a players counter, status badge, then chips, title, date, venue and price.
public struct MatchCard: View {
    let match: Match
    let onTap: () -> Void

    public init(match: Match, onTap: @escaping () -> Void) {
        self.match = match
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: Spacing.s) {
                image
                chips
                Text(verbatim: match.title.uppercased())
                    .font(AppFont.headline)
                    .foregroundStyle(.ds.textPrimary)
                    .lineLimit(1)
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        infoRow(.clock, match.kickoffCardText)
                        infoRow(.location, match.location)
                    }
                    Spacer(minLength: Spacing.m)
                    price
                }
            }
            .opacity(match.isCancelled ? 0.5 : 1)
        }
        .buttonStyle(.plain)
        .disabled(match.isCancelled)
        .accessibilityElement(children: .combine)
    }

    private var image: some View {
        ZStack(alignment: .topLeading) {
            RemoteImage(url: match.tournamentImage, cornerRadius: Radius.l) {
                ZStack {
                    Color.ds.separator
                    Text(verbatim: match.title)
                        .font(AppFont.headline)
                        .foregroundStyle(.ds.brandPrimary)
                }
            }
            .frame(height: 140)
            .clipShape(RoundedRectangle(cornerRadius: Radius.l, style: .continuous))

            Badge(
                text: Text(verbatim: "\(match.joinedPlayerCount) / \(match.totalPlayers)"),
                icon: .players,
                color: match.isAlmostFull ? .ds.statusError : .ds.accent
            )
            .padding(Spacing.m)

            if let status = statusBadge {
                status
                    .padding(Spacing.s)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
        .frame(height: 140)
    }

    private var statusBadge: Badge? {
        if match.isCancelled {
            return Badge(text: Text(L10n.Matches.cancelled), color: .ds.statusError)
        }
        if match.joinStatus {
            return Badge(text: Text(L10n.Tournament.joined), color: .ds.statusSuccess)
        }
        if match.isJoinWaitingList {
            return Badge(text: Text(L10n.Matches.waiting), color: .ds.accent)
        }
        return nil
    }

    private var chips: some View {
        HStack(spacing: Spacing.xs) {
            if match.isByChampz {
                Chip(text: Text(L10n.Matches.byChampz), background: .ds.brandDeep, foreground: .ds.brandSoft)
            }
            // Competitive = blue, Friendly = green (friendly_match_card.dart).
            Chip(
                text: Text(verbatim: match.matchTypeLabel),
                icon: match.isCompetitive ? .matchCompetitive : .matchFriendly,
                background: match.isCompetitive ? .ds.statusInfo : .ds.statusSuccess,
                foreground: .ds.onBrand
            )
            if match.isLastSpot {
                Chip(text: Text(L10n.Matches.lastSpots), background: .ds.statusError, foreground: .ds.onBrand)
            }
        }
    }

    private func infoRow(_ icon: AppIcon, _ text: String) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(icon)
                .font(.caption)
                .foregroundStyle(.ds.brandPrimary)
            Text(verbatim: text)
                .font(AppFont.body)
                .foregroundStyle(.ds.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    /// Grey box: price (discounted price in red with the original struck through), duration under it.
    private var price: some View {
        VStack(spacing: Spacing.xxs) {
            if match.discountKey == "1" {
                HStack(alignment: .lastTextBaseline, spacing: Spacing.xxs) {
                    Text(verbatim: match.effectivePrice.compact)
                        .font(AppFont.headline.weight(.bold))
                        .foregroundStyle(.ds.statusError)
                    Text(verbatim: Money(match.price ?? 0, currency: match.effectivePrice.currency).compact)
                        .font(AppFont.captionSmall.weight(.semibold))
                        .foregroundStyle(.ds.brandPrimary)
                        .strikethrough()
                }
            } else {
                Text(verbatim: match.effectivePrice.compact)
                    .font(AppFont.headline.weight(.bold))
                    .foregroundStyle(.ds.brandPrimary)
            }
            Text(verbatim: L10n.Matches.durationMinutes(match.duration))
                .font(AppFont.body.weight(.medium))
                .foregroundStyle(.ds.textPrimary)
        }
        .lineLimit(1)
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, Spacing.xs)
        .background(Color.ds.separator, in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
    }
}

/// Pill with white text over a solid color.
struct Badge: View {
    let text: Text
    var icon: AppIcon?
    let color: Color

    var body: some View {
        HStack(spacing: Spacing.xs) {
            if let icon {
                Image(icon).font(.caption2)
            }
            text.font(AppFont.captionSmall.weight(.bold))
        }
        .foregroundStyle(.ds.onBrand)
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.xs + 2)
        .background(color, in: Capsule())
    }
}

/// Small rounded label used for type and flags.
struct Chip: View {
    let text: Text
    var icon: AppIcon?
    let background: Color
    let foreground: Color

    var body: some View {
        HStack(spacing: Spacing.xs) {
            if let icon {
                Image(icon).font(.caption2)
            }
            text.font(AppFont.captionSmall.weight(.semibold))
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, Spacing.s + 2)
        .frame(height: 22)
        .background(background, in: RoundedRectangle(cornerRadius: Radius.s + 1, style: .continuous))
    }
}

#Preview("Match card") {
    var competitive = Match.preview
    competitive.matchType = .competitive
    competitive.matchTypeLabel = "Competitive"
    competitive.discountKey = "1"
    competitive.discountPrice = 24
    competitive.joinedPlayerCount = 9
    return VStack(spacing: Spacing.xl) {
        MatchCard(match: .preview) {}
        MatchCard(match: competitive) {}
    }
    .padding(Spacing.gutter)
}
