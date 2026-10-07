import SwiftUI

/// The player stats widget: the same view on My Stats and on any other player's profile.
/// Header card, PLAYER DETAILS grid, nationality and debut, goals, accolades, transfer history.
/// Screens add their own extras around it (My Stats: wallet pill and Edit Profile).
public struct PlayerStatsView<HeaderAccessory: View>: View {
    /// Whose stats these are; only changes the empty-state wording ("You haven't…" vs neutral).
    public enum Perspective: Sendable {
        case own, other
    }

    let stats: PlayerStats
    let perspective: Perspective
    let headerAccessory: HeaderAccessory

    public init(
        stats: PlayerStats,
        perspective: Perspective,
        @ViewBuilder headerAccessory: () -> HeaderAccessory = { EmptyView() }
    ) {
        self.stats = stats
        self.perspective = perspective
        self.headerAccessory = headerAccessory()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            PlayerHeaderCard(player: stats.player) { headerAccessory }
            Text(L10n.TransferMarket.playerDetails).font(AppFont.sectionTitle).foregroundStyle(.ds.textPrimary)
                .padding(.top, Spacing.s)
            StatGrid(statistics: stats.statistics)
            PersonalDetailsCard(player: stats.player)
            GoalsCard(statistics: stats.statistics)
            CollapsibleCard(L10n.TransferMarket.accolades, isInitiallyExpanded: false) {
                if stats.statistics.accolades.isEmpty {
                    EmptyLine(perspective == .own ? L10n.Profile.noTitlesOnChampz : L10n.PlayerProfile.noTitles)
                } else {
                    ForEach(Array(stats.statistics.accolades.enumerated()), id: \.offset) { _, accolade in
                        AccoladeRow(accolade: accolade)
                    }
                }
            }
            CollapsibleCard(L10n.TransferMarket.transferHistory, isInitiallyExpanded: true) {
                if stats.statistics.transfers.isEmpty {
                    EmptyLine(perspective == .own ? L10n.Profile.noTransferHistory : L10n.PlayerProfile.noTransfers)
                } else {
                    ForEach(Array(stats.statistics.transfers.enumerated()), id: \.offset) { _, transfer in
                        TransferRow(transfer: transfer)
                    }
                }
            }
        }
    }
}

// MARK: - Sections

/// Avatar, name, availability dot + club, "Position, Age N", and a trailing slot.
struct PlayerHeaderCard<Accessory: View>: View {
    let player: PublicPlayer
    @ViewBuilder let accessory: Accessory

    private var subtitle: String {
        let position = player.position?.name ?? ""
        switch (position.isEmpty, player.age()) {
        case let (false, age?): return L10n.PlayerProfile.positionAndAge(position, age: age)
        case let (true, age?): return "\(String(localized: L10n.TransferMarket.age)) \(age)"
        default: return position
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.m) {
            AvatarView(url: player.avatarUrl, name: player.fullName, size: 72)
                .padding(3)
                .overlay(Circle().strokeBorder(Color.ds.brandPrimary, lineWidth: 3))
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(verbatim: player.fullName.uppercased())
                    .font(AppFont.headline)
                    .foregroundStyle(.ds.textPrimary)
                    .lineLimit(2)
                HStack(spacing: Spacing.xs) {
                    Circle()
                        .fill(player.isAvailable ? Color.ds.statusSuccess : Color.ds.statusError)
                        .frame(width: 8, height: 8)
                        .accessibilityLabel(Text(player.isAvailable
                                ? L10n.PlayerProfile.availableForTransfer
                                : L10n.PlayerProfile.notAvailableForTransfer))
                    Text(verbatim: player.clubName.isEmpty ? String(localized: L10n.PlayerProfile.notAvailable) : player
                        .clubName)
                }
                .font(AppFont.bodyEmphasis)
                .foregroundStyle(.ds.textSecondary)
                if !subtitle.isEmpty {
                    Text(verbatim: subtitle).font(AppFont.body).foregroundStyle(.ds.textSecondary)
                }
            }
            Spacer(minLength: 0)
            accessory
        }
        .padding(Spacing.l)
        .background(Color.ds.surface, in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
    }
}

/// 2×2: matches played / won / lost, tournaments won.
struct StatGrid: View {
    let statistics: PlayerStatistics

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: Spacing.m), GridItem(.flexible())], spacing: Spacing.m) {
            tile(L10n.TransferMarket.matchesPlayed, statistics.matchesPlayed)
            tile(L10n.TransferMarket.matchesWon, statistics.matchesWon)
            tile(L10n.TransferMarket.matchesLost, statistics.matchesLost)
            tile(L10n.TransferMarket.tournamentsWon, statistics.tournamentsWon)
        }
    }

    private func tile(_ label: LocalizedStringResource, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(verbatim: "\(value)").font(AppFont.title1).foregroundStyle(.ds.brandPrimary)
            Text(label).font(AppFont.bodyEmphasis).foregroundStyle(.ds.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.l)
        .background(Color.ds.surface, in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Nationality (flag + name) and Champz debut, side by side.
struct PersonalDetailsCard: View {
    let player: PublicPlayer

    private var notAvailable: String {
        String(localized: L10n.PlayerProfile.notAvailable)
    }

    var body: some View {
        HStack(alignment: .top) {
            cell(L10n.Profile.nationality, value: {
                if let nationality = player.nationality {
                    "\(nationality.flag) \(nationality.name)".trimmingCharacters(in: .whitespaces)
                } else {
                    notAvailable
                }
            }())
            cell(L10n.TransferMarket.debut, value: player.debutText.isEmpty ? notAvailable : player.debutText)
        }
        .padding(Spacing.l)
        .background(Color.ds.surface, in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
    }

    private func cell(_ label: LocalizedStringResource, value: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label).font(AppFont.caption).foregroundStyle(.ds.textSecondary)
            Text(verbatim: value).font(AppFont.infoValue).foregroundStyle(.ds.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// Pink card: total goals, then friendlies / competitive / tournaments.
struct GoalsCard: View {
    let statistics: PlayerStatistics

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            HStack(spacing: Spacing.m) {
                Image(.football).font(.title2)
                Text(L10n.TransferMarket.totalGoals).font(AppFont.sectionTitle)
                Spacer()
                Text(verbatim: "\(statistics.goalsTotal)").font(AppFont.display)
            }
            HStack(spacing: Spacing.s) {
                tile(L10n.TransferMarket.scoredInFriendlies, statistics.goalsFriendlies)
                tile(L10n.TransferMarket.scoredInCompetitive, statistics.goalsCompetitive)
                tile(L10n.TransferMarket.scoredInTournaments, statistics.goalsTournaments)
            }
        }
        .foregroundStyle(.ds.onBrand)
        .padding(Spacing.l)
        .background(Color.ds.accent, in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
    }

    private func tile(_ label: LocalizedStringResource, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(verbatim: "\(value)").font(AppFont.title2)
            Text(label).font(AppFont.captionSmall).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.m)
        .background(Color.ds.accentDeep, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// White card with a title row that folds its content away.
struct CollapsibleCard<Content: View>: View {
    let title: LocalizedStringResource
    @ViewBuilder let content: Content
    @State private var isExpanded: Bool

    init(_ title: LocalizedStringResource, isInitiallyExpanded: Bool, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
        _isExpanded = State(initialValue: isInitiallyExpanded)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack {
                    Text(title).font(AppFont.sectionTitle).foregroundStyle(.ds.textPrimary)
                    Spacer()
                    Image(.chevronDown)
                        .foregroundStyle(.ds.brandPrimary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isHeader)
            if isExpanded {
                content
            }
        }
        .padding(Spacing.l)
        .background(Color.ds.surface, in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
    }
}

private struct EmptyLine: View {
    let text: LocalizedStringResource

    init(_ text: LocalizedStringResource) {
        self.text = text
    }

    var body: some View {
        Text(text).font(AppFont.detailBody).foregroundStyle(.ds.textTertiary)
    }
}

private struct AccoladeRow: View {
    let accolade: Accolade

    var body: some View {
        HStack(spacing: Spacing.m) {
            Image(.medal).resizable().scaledToFit().frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(verbatim: accolade.name).font(AppFont.bodyEmphasis).foregroundStyle(.ds.textPrimary)
                if !accolade.tournamentName.isEmpty {
                    Text(verbatim: accolade.tournamentName).font(AppFont.caption).foregroundStyle(.ds.textSecondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// "Eagles → Falcons" with the date under it. Always the same arrow direction
/// (the current app alternated it by row index).
private struct TransferRow: View {
    let transfer: TransferRecord

    private var notAvailable: String {
        String(localized: L10n.PlayerProfile.notAvailable)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack(spacing: Spacing.s) {
                Text(verbatim: transfer.transferredFrom.isEmpty ? notAvailable : transfer.transferredFrom)
                Image(.arrowRight).foregroundStyle(.ds.brandPrimary)
                Text(verbatim: transfer.transferredTo.isEmpty ? notAvailable : transfer.transferredTo)
            }
            .font(AppFont.bodyEmphasis)
            .foregroundStyle(.ds.textPrimary)
            if !transfer.date.isEmpty {
                Text(verbatim: transfer.date).font(AppFont.caption).foregroundStyle(.ds.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("Player stats") {
    ScrollView {
        PlayerStatsView(stats: .preview, perspective: .own).padding(Spacing.gutter)
    }
    .background(Color.ds.backgroundMuted)
}
