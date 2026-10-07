import SwiftUI

/// The venue tile on Home ("BOOK A COURT") and in the venue list (court_card.dart):
/// picture, name, "Starts from 150 QR / 60 min", location.
public struct VenueCard: View {
    let venue: Venue
    let onTap: () -> Void

    public init(venue: Venue, onTap: @escaping () -> Void) {
        self.venue = venue
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: Spacing.s) {
                RemoteImage(url: venue.gallery.first ?? "", cornerRadius: Radius.l) {
                    ZStack {
                        Color.ds.separator
                        Image(.football).font(AppFont.stateIcon).foregroundStyle(.ds.textTertiary)
                    }
                }
                .frame(height: 140)
                Text(verbatim: venue.name.uppercased())
                    .font(AppFont.headline)
                    .foregroundStyle(.ds.textPrimary)
                    .lineLimit(1)
                if let price = venue.startingPrice {
                    (Text(L10n.Court.startsFrom) + Text(verbatim: " ")
                        + Text(verbatim: price.compact).foregroundColor(.ds.brandPrimary)
                        + Text(verbatim: " / " + L10n.Courts.minutes(60)))
                        .font(AppFont.bodyEmphasis)
                        .foregroundStyle(.ds.textSecondary)
                }
                HStack(spacing: Spacing.xs) {
                    Image(.location).font(.caption).foregroundStyle(.ds.brandPrimary)
                    Text(verbatim: venue.location).font(AppFont.body).foregroundStyle(.ds.textSecondary).lineLimit(1)
                    if let distance = venue.distanceKm {
                        Text(verbatim: "| " + distance.formatted(.number.precision(.fractionLength(1))) + " km")
                            .font(AppFont.body)
                            .foregroundStyle(.ds.textSecondary)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}
