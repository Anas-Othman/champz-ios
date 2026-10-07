import Foundation
import Testing
@testable import ChampzKit

/// Scripted `ProfileRepository` for view-model tests.
actor FakeProfileRepository: ProfileRepository {
    private(set) var updates: [ProfileUpdate] = []
    /// Ids whose stats were asked for, in order.
    private(set) var statsRequests: [PlayerID] = []
    var statsResult: Result<PlayerStats, AppError> = .success(.preview)
    var current: PlayerProfile = .decode(profileJSON())
    var updateResult: Result<PlayerProfile, AppError>?

    func set(profile: PlayerProfile) {
        current = profile
    }

    func set(updateResult: Result<PlayerProfile, AppError>) {
        self.updateResult = updateResult
    }

    func profile() async throws(AppError) -> PlayerProfile {
        current
    }

    func update(_ update: ProfileUpdate) async throws(AppError) -> PlayerProfile {
        updates.append(update)
        return try (updateResult ?? .success(current)).get()
    }

    func set(statsResult: Result<PlayerStats, AppError>) {
        self.statsResult = statsResult
    }

    func stats(_ id: PlayerID) async throws(AppError) -> PlayerStats {
        statsRequests.append(id)
        return try statsResult.get()
    }

    func positions() async throws(AppError) -> [Position] {
        [
            .decode(#"{"id": "pos1", "code": "GK", "name": "Goalkeeper"}"#),
            .decode(#"{"id": "pos2", "code": "ST", "name": "Striker"}"#),
        ]
    }

    func nationalities() async throws(AppError) -> [Nationality] {
        [
            .decode(#"{"id": "c1", "code": "QA", "name": "Qatar", "nationality": "Qatari"}"#),
            .decode(#"{"id": "c2", "code": "EG", "name": "Egypt", "nationality": "Egyptian"}"#),
        ]
    }
}

/// A profile as `GET /profile/` returns it.
func profileJSON(email: String = "", phone: String = "55512345") -> String {
    #"{"id": "01J9PLAYER0000000000000001", "first_name": "Anas", "last_name": "E", "full_name": "Anas E", "#
        + #""email": "\#(email)", "country_code": "974", "phone": "\#(phone)", "#
        + #""avatar_url": "https://cdn.champz.me/a.png", "gender": "male", "date_of_birth": null, "#
        + #""nationality": null, "city": null, "position": null, "is_available": false, "#
        + #""is_profile_complete": false, "club_name": null}"#
}

struct ProfileModelTests {
    @Test func decodesTheBackendShape() {
        let json = profileJSON().replacingOccurrences(
            of: #""position": null"#,
            with: #""position": {"id": 3, "name": "Striker"}"#
        )
        let profile = PlayerProfile.decode(json)
        #expect(profile.dialCode == "+974")
        #expect(profile.birthDate == nil)
        #expect(profile.nationality == nil)
        #expect(profile.position?.id.raw == "3") // integer ids decode too
        #expect(profile.clubName.isEmpty)
    }

    @Test func nameIsSplitAtTheFirstSpace() {
        let update = ProfileUpdate(fullName: "  Anas Ezzat Ali ")
        #expect(update.fields["first_name"] == "Anas")
        #expect(update.fields["last_name"] == "Ezzat Ali")
        #expect(ProfileUpdate(fullName: "Anas").fields["last_name"] == "")
    }

    @Test func onlyWhatIsSetIsSent() throws {
        let birth = try #require(DateOfBirth.date(from: "1995-03-07"))
        let update = ProfileUpdate(
            fullName: "Anas E",
            phone: PhoneNumber(dial: "+974", number: "55512345"),
            dateOfBirth: birth,
            nationalityID: CountryID("c1")
        )
        #expect(update.fields == [
            "first_name": "Anas", "last_name": "E", "phone": "55512345", "country_code": "+974",
            "date_of_birth": "1995-03-07", "nationality": "c1",
        ])
    }

    @Test func multipartBodyCarriesFieldsAndThePhoto() throws {
        let endpoint = ProfileAPI.update(ProfileUpdate(fullName: "Anas E", avatar: Data("JPEG".utf8)))
        let contentType = try #require(endpoint.headers["Content-Type"])
        #expect(contentType.hasPrefix("multipart/form-data; boundary="))
        let data = try #require(endpoint.body)
        let body = try #require(String(bytes: data, encoding: .utf8))
        #expect(body.contains("name=\"first_name\"\r\n\r\nAnas\r\n"))
        #expect(body.contains("name=\"avatar\"; filename=\"avatar.jpg\"\r\nContent-Type: image/jpeg\r\n\r\nJPEG\r\n"))
        #expect(endpoint.method == .patch)
    }

    @Test func conflictNamingAFieldBecomesAFieldError() {
        let body = #"{"error": {"code": "02018", "message": "Conflict", "details": "That number is taken.", "#
            + #""errors": [{"field": "phone", "message": "That number is taken."}]}}"#
        #expect(APIErrorMapper.map(statusCode: 409, body: Data(body.utf8))
            == .validation([FieldError(field: "phone", message: "That number is taken.")]))
    }
}

@MainActor
struct EditProfileViewModelTests {
    private struct Harness {
        let viewModel: EditProfileViewModel
        let repository: FakeProfileRepository
        let router: AppRouter
        let changes: DataChanges
    }

    private func make(_ profile: PlayerProfile? = nil) async -> Harness {
        let repository = FakeProfileRepository()
        if let profile {
            await repository.set(profile: profile)
        }
        let router = AppRouter()
        router.present(.editProfile)
        let changes = DataChanges()
        let viewModel = EditProfileViewModel(
            profiles: repository,
            router: router,
            toasts: ToastCenter(),
            changes: changes
        )
        await viewModel.load()
        return Harness(viewModel: viewModel, repository: repository, router: router, changes: changes)
    }

    @Test func fillsTheFormWithoutInventingValues() async {
        let viewModel = await make().viewModel
        #expect(viewModel.name == "Anas E")
        #expect(viewModel.dial == CountryDialCodes.qatar)
        #expect(viewModel.nationality == nil) // not pre-picked "Qatari"
        #expect(viewModel.position == nil) // not pre-picked "Goalkeeper"
        #expect(viewModel.positions.count == 2)
        #expect(viewModel.isPhoneLocked)
        #expect(viewModel.isEmailLocked == false)
    }

    @Test func requiredFieldsBlockSaving() async {
        let harness = await make()
        let viewModel = harness.viewModel
        let repository = harness.repository
        await viewModel.save()
        #expect(await repository.updates.isEmpty)
        #expect(viewModel.errors[.dateOfBirth] != nil)
        #expect(viewModel.errors[.nationality] != nil)
    }

    @Test func savingSendsTheFormAndClosesTheSheet() async {
        let harness = await make()
        let viewModel = harness.viewModel
        let repository = harness.repository
        viewModel.birthDate = DateOfBirth.date(from: "1995-03-07")
        viewModel.nationality = viewModel.nationalities.first
        viewModel.email = "anas@champz.me"
        viewModel.phone = "99999999" // locked: must not be sent
        await viewModel.save()

        let sent = await repository.updates.first
        #expect(sent?.email == "anas@champz.me")
        #expect(sent?.phone == nil)
        #expect(sent?.nationalityID == CountryID("c1"))
        #expect(harness.router.sheet == nil)
        #expect(harness.changes.profileVersion == 1)
    }

    @Test func aTakenPhoneIsShownUnderThePhoneBox() async {
        let harness = await make(.decode(profileJSON(email: "a@b.co", phone: "")))
        let viewModel = harness.viewModel
        let repository = harness.repository
        await repository.set(updateResult: .failure(.validation([FieldError(field: "phone", message: "Taken")])))
        viewModel.birthDate = DateOfBirth.date(from: "1995-03-07")
        viewModel.nationality = viewModel.nationalities.first
        viewModel.phone = "55512345"
        await viewModel.save()

        #expect(await repository.updates.first?.phone == PhoneNumber(dial: "+974", number: "55512345"))
        #expect(viewModel.errors[.phone] == "Taken")
        #expect(harness.router.sheet == .editProfile) // stays open to fix it
    }
}
