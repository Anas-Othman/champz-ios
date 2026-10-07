import MapKit
import SwiftUI

// Pieces of the match detail screen, each matching its Flutter counterpart.

/// 280pt image with white back / share buttons (hero of open_to_play_match_screen.dart).
struct MatchHero: View {
    let match: Match
    let shareMessage: String?
    let onBack: () -> Void

    var body: some View {
        RemoteImage(url: match.tournamentImage) {
            ZStack {
                Color.ds.separator
                Image(.football).font(AppFont.stateIcon).foregroundStyle(.ds.textTertiary)
            }
        }
        .frame(height: 280)
        .overlay(alignment: .top) {
            HStack {
                Button(action: onBack) { HeroButtonLabel(icon: .back) }
                Spacer()
                if !match.isFinished, let shareMessage {
                    ShareLink(item: shareMessage) { HeroButtonLabel(icon: .brandShare) }
                }
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.top, 62)
        }
    }
}

/// 42×42 white rounded square holding an icon.
struct HeroButtonLabel: View {
    let icon: AppIcon

    var body: some View {
        Image(icon)
            .resizable()
            .scaledToFit()
            .frame(width: 18, height: 18)
            .foregroundStyle(.ds.textPrimary)
            .frame(width: 42, height: 42)
            .background(Color.ds.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// Pink 24pt icon + 18pt pink text (date and venue lines).
struct DetailLine: View {
    let icon: AppIcon
    let text: String

    var body: some View {
        HStack(spacing: Spacing.s) {
            Image(icon).resizable().scaledToFit().frame(width: 24, height: 24)
            Text(verbatim: text).font(AppFont.detailLine)
        }
        .foregroundStyle(.ds.accent)
    }
}

/// White card: Pitch · No. courts · Price.
struct MatchInfoCard: View {
    let match: Match

    /// The info card shows the list price, not the discounted one (current app behaviour).
    private var listPrice: Decimal {
        match.price ?? 0
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            cell(L10n.Court.pitch, match.surfaceType.isEmpty ? "N/A" : match.surfaceType)
            cell(L10n.Court.noOfCourts, String(match.noOfCourts))
            cell(
                L10n.Court.price,
                listPrice == 0 ? String(localized: L10n.FriendlyMatch.free) : Money(
                    listPrice,
                    currency: Money.defaultCurrency
                ).compact,
                color: listPrice == 0 ? .ds.statusSuccess : .ds.textPrimary
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, Spacing.l)
        .background {
            RoundedRectangle(cornerRadius: Radius.l, style: .continuous)
                .fill(Color.ds.surface)
                .shadow(color: .ds.shadow, radius: 6, y: 4)
        }
    }

    private func cell(_ label: LocalizedStringResource, _ value: String, color: Color = .ds.textPrimary) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label).font(AppFont.infoLabel).foregroundStyle(.ds.textPrimary)
            Text(verbatim: value).font(AppFont.infoValue).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// White row: up to three overlapping avatars, "+N Players have joined", chevron.
/// Used for match players, tournament players and tournament teams.
struct JoinedBanner<Item: HasAvatar & Identifiable>: View {
    let items: [Item]
    /// "Players have joined" / "Teams have joined" — gets the count to pick singular or plural.
    let label: (Int) -> LocalizedStringResource
    let onTap: () -> Void
    var onItemTap: ((Item) -> Void)?

    private var shown: [Item] {
        Array(items.prefix(3))
    }

    private var count: String {
        items.count > 3 ? "+ \(items.count - shown.count)" : "\(items.count)"
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.s) {
                HStack(spacing: -12) {
                    ForEach(shown) { item in
                        AvatarView(url: item.image, name: item.name, size: 36)
                            .overlay(Circle().strokeBorder(Color.ds.surface, lineWidth: 2))
                            .onTapGesture {
                                if let onItemTap {
                                    onItemTap(item)
                                } else {
                                    onTap()
                                }
                            }
                    }
                }
                (Text(verbatim: count + " ") + Text(label(items.count)))
                    .font(AppFont.detailBody)
                    .foregroundStyle(.ds.textPrimary)
                Spacer()
                Image(.chevronRight).font(.footnote).foregroundStyle(.ds.textTertiary)
            }
            .padding(.horizontal, Spacing.s)
            .padding(.vertical, Spacing.m)
            .background(Color.ds.surface, in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// 210pt map with the venue pin and a full-width "Get Directions" bar inside its bottom edge.
/// Banner labels, singular or plural by count.
enum JoinedLabel {
    static func players(_ count: Int) -> LocalizedStringResource {
        count > 1 ? L10n.Tournament.playersHaveJoined : L10n.Tournament.playerHasJoined
    }

    static func teams(_: Int) -> LocalizedStringResource {
        L10n.Tournament.teamsHaveJoined
    }
}

struct MapCard: View {
    let latitude: Double
    let longitude: Double
    let title: String

    private var coordinate: CLLocationCoordinate2D {
        .init(latitude: latitude, longitude: longitude)
    }

    var body: some View {
        Map(initialPosition: .region(MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 1200,
            longitudinalMeters: 1200
        ))) {
            Marker(title, coordinate: coordinate)
        }
        .frame(height: 210)
        .clipShape(RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
        .overlay(alignment: .bottom) {
            Button(action: openDirections) {
                Text(L10n.Court.getDirections)
                    .font(AppFont.buttonLarge)
                    .foregroundStyle(.ds.brandPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Radius.l, style: .continuous).strokeBorder(
                        Color.ds.hairline,
                        lineWidth: 1.5
                    ))
            }
            .padding(.horizontal, 6)
            .padding(.bottom, Spacing.xs)
        }
    }

    /// Native Apple Maps directions (the Flutter app opens a Google Maps URL).
    private func openDirections() {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        item.name = title
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }
}

/// White card: ringed avatar, name, phone, then Call / WhatsApp buttons.
struct OrganizerCard: View {
    let organizer: MatchOrganizer
    let fallbackPhone: String
    @Environment(\.openURL) private var openURL

    private var phone: String {
        organizer.phone.isEmpty ? fallbackPhone : organizer.phone
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: Spacing.m) {
                AvatarView(url: organizer.image, name: organizer.name, size: 51)
                    .overlay(Circle().strokeBorder(Color.ds.brandPrimary, lineWidth: 3))
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(verbatim: organizer.name.isEmpty ? String(localized: L10n.Matches.organizer) : organizer.name)
                        .font(AppFont.infoValue)
                        .foregroundStyle(.ds.textStrong)
                    if !phone.isEmpty {
                        Link(destination: Self.telURL(phone)) {
                            Text(verbatim: phone).font(AppFont.detailBody).foregroundStyle(.ds.textPrimary)
                        }
                    }
                }
            }
            if !phone.isEmpty {
                HStack(spacing: 10) {
                    ContactButton(icon: .phone, title: L10n.Matches.call) { openURL(Self.telURL(phone)) }
                    ContactButton(icon: .whatsApp, title: L10n.Matches.whatsApp) {
                        if let url = URL(string: "https://wa.me/\(phone.filter(\.isNumber))") {
                            openURL(url)
                        }
                    }
                }
            }
        }
        .padding(Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ds.surface, in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
    }

    static func telURL(_ phone: String) -> URL {
        URL(string: "tel:\(phone.filter { $0.isNumber || $0 == "+" })") ?? URL(fileURLWithPath: "/")
    }
}

/// 44pt outlined button: purple icon + dark label.
struct ContactButton: View {
    let icon: AppIcon
    let title: LocalizedStringResource
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.s) {
                Image(icon).resizable().scaledToFit().frame(width: 20, height: 20).foregroundStyle(.ds.brandPrimary)
                Text(title).font(AppFont.bodyEmphasis).foregroundStyle(.ds.textStrong)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .overlay(RoundedRectangle(cornerRadius: Radius.m, style: .continuous).strokeBorder(
                Color.ds.brandPrimary.opacity(0.35),
                lineWidth: 1.5
            ))
        }
        .buttonStyle(.plain)
    }
}

extension String {
    /// Good enough for the match description: drop tags, turn `<br>` into newlines.
    var strippingHTML: String {
        replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
