import SwiftUI

/// Compact header for what is being bought: image, name, date, venue.
/// Used on the registration and booking-summary screens of every paid flow.
struct PurchaseHeaderCard: View {
    let image: String
    let title: String
    let date: String
    let venue: String
    let placeholder: AppIcon

    var body: some View {
        HStack(spacing: Spacing.m) {
            RemoteImage(url: image, cornerRadius: Radius.m) {
                ZStack {
                    Color.ds.separator
                    Image(placeholder).resizable().scaledToFit().frame(width: 24, height: 24)
                        .foregroundStyle(.ds.textTertiary)
                }
            }
            .frame(width: 72, height: 72)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(verbatim: title.uppercased()).font(AppFont.infoValue).foregroundStyle(.ds.textPrimary)
                    .lineLimit(1)
                Text(verbatim: date).font(AppFont.caption).foregroundStyle(.ds.textSecondary)
                Text(verbatim: venue).font(AppFont.caption).foregroundStyle(.ds.textSecondary).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(Spacing.l)
        .background {
            RoundedRectangle(cornerRadius: Radius.l, style: .continuous)
                .fill(Color.ds.surface)
                .shadow(color: .ds.shadow, radius: 5, y: 2)
        }
    }
}

extension PurchaseHeaderCard {
    init(match: Match) {
        self.init(
            image: match.tournamentImage,
            title: match.title,
            date: match.kickoffDetailText,
            venue: match.venueName,
            placeholder: .football
        )
    }

    init(courtBooking draft: CourtBookingDraft) {
        self.init(
            image: draft.venue.gallery.first ?? "",
            title: draft.venue.name,
            date: draft.whenText,
            venue: [draft.court.name, draft.court.courtType].filter { !$0.isEmpty }.joined(separator: " · "),
            placeholder: .football
        )
    }

    /// A booking someone else made (court invite).
    init(booking: CourtBooking) {
        self.init(
            image: "",
            title: booking.venueName,
            date: booking.whenText,
            venue: booking.courtName,
            placeholder: .football
        )
    }

    init(tournament: Tournament) {
        self.init(
            image: tournament.image,
            title: tournament.name,
            date: tournament.cardDateText,
            venue: tournament.venueText,
            placeholder: .tournamentTrophy
        )
    }
}
