import Foundation
import Testing
@testable import ChampzKit

/// FCM delivers every data value as a string; the payload must route like the feed does.
struct PushPayloadTests {
    @Test func aBookingInviteOpensTheInviteAndCarriesItsNotification() {
        let payload = PushPayload(["notify_type": "4", "notification_id": "n1", "booking_id": "b9", "court_id": "c1"])
        #expect(payload.notificationID == NotificationID("n1"))
        #expect(payload.route == .bookingInvite(BookingID("b9")))
    }

    @Test func matchesTournamentsAndOffersRouteLikeTheFeed() {
        #expect(PushPayload(["notify_type": "5", "match_id": "m1"]).route == .matchDetail(MatchID("m1")))
        #expect(PushPayload(["notify_type": "0", "tournament_id": "t1"]).route == .tournamentDetail(TournamentID("t1")))
        // Older payloads name the sender `player_id`.
        #expect(PushPayload(["notify_type": "2", "player_id": "p5"]).route == .playerProfile(PlayerID("p5")))
    }

    @Test func anythingElseOpensTheNotificationsList() {
        #expect(PushPayload(["notify_type": "9"]).route == .notifications)
        #expect(PushPayload([:]).route == .notifications)
        #expect(PushPayload([:]).notificationID == nil)
    }

    @Test func numbersAreReadToo() {
        #expect(PushPayload(["notify_type": NSNumber(value: 5), "match_id": "m1"]).route == .matchDetail(MatchID("m1")))
    }

    @Test func registeringSendsTheTokenForIOS() throws {
        let data = try #require(NotificationsAPI.registerDevice(token: "fcm-123").body)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: String])
        #expect(json == ["token": "fcm-123", "platform": "ios"])
    }
}

@MainActor
struct PushRoutingTests {
    @Test func aTapBeforeSignInOpensAfterIt() {
        let router = AppRouter()
        router.open(.push(.matchDetail(MatchID("m1"))), isSignedIn: false)
        #expect(router.paths[.home] == nil || router.paths[.home]?.isEmpty == true)
        router.replayPendingDeepLink()
        #expect(router.paths[.home]?.last == .matchDetail(MatchID("m1")))
    }
}
