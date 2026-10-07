import SwiftUI

// Pieces of the tournament page, each matching its Flutter counterpart.

/// Image with back / share buttons, and the Joined · Teams · Players chips on its bottom edge.
struct TournamentHero: View {
    let tournament: Tournament
    let shareMessage: String?
    let onBack: () -> Void

    var body: some View {
        RemoteImage(url: tournament.image) {
            ZStack {
                Color.ds.separator
                Image(.tournamentTrophy).resizable().scaledToFit().frame(width: 40, height: 40)
                    .foregroundStyle(.ds.textTertiary)
            }
        }
        .frame(height: 296)
        .overlay(alignment: .top) {
            HStack {
                Button(action: onBack) { HeroButtonLabel(icon: .back) }
                Spacer()
                if let shareMessage {
                    ShareLink(item: shareMessage) { HeroButtonLabel(icon: .brandShare) }
                }
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.top, 62)
        }
        .overlay(alignment: .bottomTrailing) {
            HStack(spacing: Spacing.s) {
                if tournament.isJoined {
                    HeroChip(icon: .checkCircle, title: L10n.Tournament.joined, tint: .ds.statusSuccess)
                }
                HeroChip(
                    icon: .playersFilled,
                    title: L10n.Tournament.teams,
                    value: "\(tournament.joinedTeams)/\(tournament.noOfTeams)"
                )
                HeroChip(
                    icon: .person,
                    title: L10n.Court.players,
                    value: "\(tournament.joinedPayers)/\(tournament.totalPayers)"
                )
            }
            .padding(.trailing, Spacing.xl)
            .padding(.bottom, 20)
        }
    }
}

/// 48pt light chip: icon, a label, and an optional "joined/total" count.
struct HeroChip: View {
    let icon: AppIcon
    let title: LocalizedStringResource
    var value: String?
    var tint: Color = .ds.brandPrimary

    var body: some View {
        HStack(spacing: 6) {
            Image(icon).resizable().scaledToFit().frame(width: 20, height: 20).foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(AppFont.captionSmall.weight(.bold)).foregroundStyle(tint)
                if let value {
                    Text(verbatim: value).font(AppFont.captionSmall.weight(.bold)).foregroundStyle(.ds.textPrimary)
                }
            }
        }
        .padding(.horizontal, Spacing.l)
        .frame(height: 48)
        .background(Color.ds.backgroundMuted, in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
    }
}

/// Grey box shown when the player is over the tournament's age limit.
struct AgeNotice: View {
    let maxAge: Int

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(L10n.Tournament.notEligibleToJoin).font(AppFont.bodyEmphasis)
            (Text(verbatim: L10n.Tournaments.maxAge(maxAge) + " ") + Text(L10n.Tournament.maxAgeMessage))
                .font(AppFont.caption)
        }
        .foregroundStyle(.ds.textSecondary)
        .padding(Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.ds.textSecondary.opacity(0.1),
            in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous)
        )
    }
}

/// The pink card: N DAYS, from → to, the prize, then Teams · Groups · Type.
struct TournamentInfoCard: View {
    let tournament: Tournament

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let days = tournament.days {
                Text(verbatim: L10n.Tournaments.dayCount(days))
                    .font(AppFont.sectionTitle)
                    .foregroundStyle(.ds.brandPrimary)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(Color.ds.surface, in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
                    .padding(.bottom, 10)
            }
            dates
            if let prize = tournament.prize {
                DashedLine().padding(.vertical, Spacing.xl)
                HStack(spacing: Spacing.m) {
                    Image(.medal).resizable().scaledToFit().frame(width: 31, height: 31)
                    Text(verbatim: prize.compact).font(AppFont.screenTitle)
                }
                .frame(maxWidth: .infinity)
            }
            DashedLine().padding(.vertical, Spacing.xl)
            stats
        }
        .foregroundStyle(.ds.onBrand)
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                Color.ds.accent
                Image(.champzLetters).resizable().scaledToFill()
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }

    @ViewBuilder
    private var dates: some View {
        if tournament.isSingleDay {
            Text(verbatim: [tournament.startDayText, tournament.startTimeText].filter { !$0.isEmpty }
                .joined(separator: " – ").uppercased())
                .font(AppFont.sectionTitle)
                .frame(maxWidth: .infinity)
        } else {
            HStack(alignment: .top) {
                dateBlock(L10n.Tournament.from, tournament.startDayText, tournament.startTimeText)
                dateBlock(L10n.Tournament.to, tournament.endDayText, tournament.endTimeText)
            }
        }
    }

    private func dateBlock(_ label: LocalizedStringResource, _ day: String, _ time: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(label).font(AppFont.caption).opacity(0.8)
            Text(verbatim: day.uppercased()).font(AppFont.sectionTitle)
            Text(verbatim: time).font(AppFont.bodyEmphasis)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var stats: some View {
        HStack(alignment: .top) {
            stat(L10n.Tournament.teams, "\(tournament.noOfTeams)")
            // Hidden when the group size is unset (0) — the current app divided by it.
            if let groups = tournament.groupCount {
                stat(
                    L10n.Tournament.groups,
                    "\(groups)",
                    subtitle: L10n.Tournaments.teamsPerGroup(tournament.teamsPerGroup)
                )
            }
            stat(L10n.Tournament.type, tournament.teamSizeText)
        }
    }

    private func stat(_ label: LocalizedStringResource, _ value: String, subtitle: String? = nil) -> some View {
        VStack(spacing: Spacing.xxs) {
            Text(label).font(AppFont.caption).opacity(0.8)
            Text(verbatim: value).font(AppFont.screenTitle)
            if let subtitle {
                Text(verbatim: subtitle).font(AppFont.captionSmall).opacity(0.8)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// White dashed divider used inside the pink card.
struct DashedLine: View {
    var body: some View {
        Line()
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
            .frame(height: 1)
            .opacity(0.6)
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            Path { path in
                path.move(to: CGPoint(x: rect.minX, y: rect.midY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            }
        }
    }
}

/// Sticky bottom bar: "Join for 50 QR", "Slot Full" (disabled) or "Leave Tournament".
struct TournamentActionBar: View {
    let tournament: Tournament
    let isWorking: Bool
    let onPrimary: () -> Void

    private var isLeaving: Bool {
        tournament.primaryAction == .leave
    }

    var body: some View {
        AppButton(title, style: isLeaving ? .destructiveOutline : .primary, isLoading: isWorking, action: onPrimary)
            .disabled(tournament.primaryAction == .full)
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.l)
            .padding(.bottom, 34)
            .background(isLeaving ? Color.clear : Color.ds.surface)
    }

    private var title: LocalizedStringResource {
        switch tournament.primaryAction {
        case .leave: L10n.Tournament.leaveTournamentAction
        case .full: L10n.Tournament.slotFull
        case .join, .none: LocalizedStringResource(stringLiteral: L10n.Tournaments.joinFor(tournament.price.compact))
        }
    }
}
