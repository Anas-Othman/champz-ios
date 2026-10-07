import SwiftUI

/// "About the venue" (book_court_details_more_screen.dart): description, details, contact, map.
public struct VenueInfoView: View {
    let venue: Venue
    @Environment(\.openURL) private var openURL

    public init(venue: Venue) {
        self.venue = venue
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                if !venue.description.isEmpty {
                    Text(verbatim: venue.description.strippingHTML)
                        .font(AppFont.detailBody)
                        .foregroundStyle(.ds.textSecondary)
                }
                details
                if !venue.contactNumber.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        Text(L10n.Courts.needHelp).font(AppFont.sectionTitle).foregroundStyle(.ds.textPrimary)
                        ContactButton(icon: .phone, title: L10n.Matches.call) {
                            openURL(OrganizerCard.telURL(venue.contactNumber))
                        }
                    }
                }
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text(L10n.Court.location).font(AppFont.sectionTitle).foregroundStyle(.ds.textPrimary)
                    Text(verbatim: venue.location).font(AppFont.detailBody).foregroundStyle(.ds.textSecondary)
                    // Real coordinates only (the current app fell back to a fixed point in Doha).
                    if let coordinate = venue.coordinate {
                        MapCard(latitude: coordinate.latitude, longitude: coordinate.longitude, title: venue.name)
                    }
                }
            }
            .padding(Spacing.gutter)
        }
        .background(Color.ds.backgroundMuted)
        .navigationTitle(Text(verbatim: venue.name))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var details: some View {
        HStack(alignment: .top, spacing: 10) {
            cell(
                L10n.Court.pitch,
                venue.surfaceType.isEmpty ? String(localized: L10n.PlayerProfile.notAvailable) : venue.surfaceType
            )
            cell(L10n.Court.noOfCourts, String(max(venue.noOfCourts, venue.courts.count)))
            cell(L10n.Court.price, venue.startingPrice?.compact ?? String(localized: L10n.PlayerProfile.notAvailable))
        }
        .padding(Spacing.l)
        .background(Color.ds.surface, in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
    }

    private func cell(_ label: LocalizedStringResource, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label).font(AppFont.infoLabel).foregroundStyle(.ds.textPrimary)
            Text(verbatim: value).font(AppFont.infoValue).foregroundStyle(.ds.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
