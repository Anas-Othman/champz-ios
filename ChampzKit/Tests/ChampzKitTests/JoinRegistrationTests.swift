import Foundation
import Testing
@testable import ChampzKit

// MARK: - Registration & wire format

@MainActor
struct JoinRegistrationTests {
    @Test func totalsUseTheServerFeeAndDiscountedPrice() {
        var match = Match.preview
        match.discountKey = "1"
        match.discountPrice = 24
        let draft = JoinDraft(
            match: match,
            booking: BookingInfo(),
            friends: [],
            guestEmail: "g@b.co",
            fee: Money(2, currency: "QAR")
        )
        #expect(draft.partySize == 2)
        #expect(draft.subtotal == Money(48, currency: "QAR"))
        #expect(draft.total == Money(50, currency: "QAR"))
    }

    @Test func joinBodyMatchesTheContract() throws {
        let body = try JSONEncoder.api().encode(JoinBody(joinDraft(friends: 2, guest: true), method: .online))
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["payment_method"] as? String == "online")
        #expect(json["friend_ids"] as? [String] == ["f0", "f1"])
        #expect((json["guests"] as? [[String: String]])?.first == ["name": "Guest", "email": "g@b.co"])
        #expect(json["booking_mobile_no"] as? String == "+974 55551234")
        #expect(json["team_number"] == nil)
        #expect(json["amount"] == nil) // the server prices the join

        let solo = try JSONEncoder.api().encode(JoinBody(joinDraft(), method: .wallet))
        let soloJSON = try #require(JSONSerialization.jsonObject(with: solo) as? [String: Any])
        #expect(soloJSON["friend_ids"] == nil)
        #expect(soloJSON["guests"] == nil)
    }

    @Test func joinRequestNeedsItsMoneyFields() {
        #expect(throws: DecodingError.self) {
            try JSONDecoder.api().decode(
                JoinRequest.self,
                from: Data(#"{"id": "jr1", "amount": "30.00", "service_fee": "2.00"}"#.utf8)
            )
        }
    }

    @Test func checkoutBodyCarriesPurposeAndWalletChoice() throws {
        let data = try JSONEncoder.api().encode(CheckoutBody(.friendlyGameJoin("jr1"), useWallet: true))
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["purpose"] as? String == "friendly_game_join")
        #expect(json["join_request_id"] as? String == "jr1")
        #expect(json["use_wallet"] as? Bool == true)
        #expect(json["channel"] as? String == "app")
    }

    @Test func registrationValidatesLikeTheCurrentApp() async {
        let viewModel = JoinRegistrationViewModel(
            matchID: Match.preview.id, isWaitingList: false, matches: PreviewMatchRepository(),
            auth: FakeAuthRepository(),
            content: FakeContentRepository(), router: AppRouter(), toasts: ToastCenter()
        )
        await viewModel.load()
        viewModel.booking.name = ""
        viewModel.booking.email = "bad"
        viewModel.booking.phone = "1234"
        #expect(!viewModel.validate())
        #expect(Set(viewModel.errors.keys) == [.name, .email, .phone])
        #expect(viewModel.fee == Money(2, currency: "QAR"))
        #expect(viewModel.maxFriends == 2) // preview: 3 spots left, minus me

        viewModel.isGuestSelected = true
        #expect(viewModel.maxFriends == 1)
        #expect(!viewModel.validate())
        #expect(viewModel.guestEmailError != nil) // guest selected without an email
    }

    @Test func bookingInfoIsSharedValidationForEveryFlow() {
        var info = BookingInfo()
        #expect(Set(info.validate().keys) == [.name, .email, .phone])
        info.name = "  Anas  "
        info.email = "anas@champz.me"
        info.phone = "5555123"
        #expect(info.validate().keys.contains(.phone)) // 7 digits: too short
        info.phone = "55551234"
        #expect(info.validate().isEmpty)
        #expect(info.trimmedName == "Anas")
        #expect(info.formattedPhone == "+974 55551234")

        let prefilled = BookingInfo(user: AccountUser(
            id: "p1",
            firstName: "Omar",
            lastName: "Ali",
            email: "o@b.co",
            countryCode: "+20",
            phone: "1001234567"
        ))
        #expect(prefilled.name == "Omar Ali")
        #expect(prefilled.country.dial == "+20")
    }
}
