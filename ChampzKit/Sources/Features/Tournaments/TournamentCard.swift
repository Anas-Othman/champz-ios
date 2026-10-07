import SwiftUI

/// The tournament tile used by the Home "Upcoming tournaments" row and the tournaments list.
/// Same shape as `MatchCard`: image with badges, name, date, venue, and a grey price box.
public struct TournamentCard: View {
    let tournament: Tournament
    let onTap: () -> Void

    public init(tournament: Tournament, onTap: @escaping () -> Void) {
        self.tournament = tournament
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: Spacing.s) {
                image
                Text(verbatim: tournament.name.uppercased())
                    .font(AppFont.headline)
                    .foregroundStyle(.ds.textPrimary)
                    .lineLimit(1)
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        infoRow(.clock, tournament.cardDateText)
                        infoRow(.location, tournament.venueText)
                    }
                    Spacer(minLength: Spacing.m)
                    price
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    private var image: some View {
        ZStack(alignment: .topLeading) {
            RemoteImage(url: tournament.image, cornerRadius: Radius.l) {
                ZStack {
                    Color.ds.separator
                    Image(.tournamentTrophy).resizable().scaledToFit().frame(width: 40, height: 40)
                        .foregroundStyle(.ds.textTertiary)
                }
            }
            .frame(height: 140)

            Badge(
                text: Text(verbatim: String(localized: L10n.Tournaments.tournament).uppercased()),
                icon: .tournamentTrophy,
                color: .ds.accent
            )
            .padding(Spacing.m)

            if tournament.isJoined {
                Badge(text: Text(L10n.Tournament.joined), color: .ds.statusSuccess)
                    .padding(Spacing.s)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
        .frame(height: 140)
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

    /// Grey box: fee, "Per player" under it.
    private var price: some View {
        VStack(spacing: Spacing.xxs) {
            Text(verbatim: tournament.price.compact)
                .font(AppFont.headline.weight(.bold))
            Text(L10n.Home.perPlayer)
                .font(AppFont.captionSmall.weight(.medium))
        }
        .foregroundStyle(.ds.brandPrimary)
        .lineLimit(1)
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, Spacing.xs)
        .background(Color.ds.separator, in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
    }
}

#Preview("Tournament card") {
    var joined = Tournament.preview
    joined.joinStatus = 1
    return VStack(spacing: Spacing.xl) {
        TournamentCard(tournament: .preview) {}
        TournamentCard(tournament: joined) {}
    }
    .padding(Spacing.gutter)
}
