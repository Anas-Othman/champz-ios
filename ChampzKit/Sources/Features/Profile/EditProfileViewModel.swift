import Foundation
import Observation

/// "My Profile" (edit_profile_screen.dart): shows the profile and saves changes.
/// Email and phone can only be added, not changed, as in the current app.
@MainActor
@Observable
public final class EditProfileViewModel {
    public enum Field: Hashable, Sendable {
        case name, email, phone, dateOfBirth, nationality, position
    }

    public private(set) var state: Loadable<PlayerProfile> = .idle
    public private(set) var positions: [Position] = []
    public private(set) var nationalities: [Nationality] = []
    public private(set) var isSaving = false
    public private(set) var errors: [Field: String] = [:]

    // The form.
    public var name = ""
    public var email = ""
    public var dial = CountryDialCodes.qatar
    public var phone = ""
    public var birthDate: Date?
    public var nationality: Nationality?
    public var position: Position?
    /// A newly picked photo as JPEG; nil keeps the current one.
    public private(set) var photo: Data?

    private let profiles: any ProfileRepository
    private let router: AppRouter
    private let toasts: ToastCenter
    private let changes: DataChanges?

    public init(
        profiles: any ProfileRepository,
        router: AppRouter,
        toasts: ToastCenter,
        changes: DataChanges? = nil
    ) {
        self.profiles = profiles
        self.router = router
        self.toasts = toasts
        self.changes = changes
    }

    public var profile: PlayerProfile? {
        state.value
    }

    /// Set once; can be added but not changed here.
    public var isEmailLocked: Bool {
        !(profile?.email.isEmpty ?? true)
    }

    public var isPhoneLocked: Bool {
        !(profile?.phone.isEmpty ?? true)
    }

    /// The profile plus the two pick lists. A failed list leaves its picker empty, not the screen broken.
    public func load() async {
        guard case .idle = state else { return }
        state = .loading
        do {
            async let profile = profiles.profile()
            async let positions = try? profiles.positions()
            async let nationalities = try? profiles.nationalities()
            let loaded = try await profile
            self.positions = await positions ?? []
            self.nationalities = await nationalities ?? []
            fill(from: loaded)
            state = .loaded(loaded)
        } catch let error as AppError {
            state = .failed(error)
        } catch {
            state = .failed(.unknown)
        }
    }

    public func setPhoto(_ jpeg: Data) {
        photo = jpeg
    }

    public func edited(_ field: Field) {
        errors[field] = nil
    }

    public func save() async {
        guard !isSaving, validate() else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            let saved = try await profiles.update(makeUpdate())
            state = .loaded(saved)
            photo = nil
            changes?.profileChanged()
            toasts.show(Toast(.success, L10n.EditProfile.profileUpdated))
            router.dismissSheet()
        } catch let .validation(fieldErrors) {
            show(fieldErrors)
        } catch {
            toasts.show(error)
        }
    }

    public func close() {
        router.dismissSheet()
    }

    // MARK: - Helpers

    /// What gets sent. Email and phone only when the player is adding them.
    func makeUpdate() -> ProfileUpdate {
        let newEmail = email.trimmingCharacters(in: .whitespaces)
        let newPhone = phone.trimmingCharacters(in: .whitespaces)
        return ProfileUpdate(
            fullName: name,
            email: isEmailLocked || newEmail.isEmpty ? nil : newEmail,
            phone: isPhoneLocked || newPhone.isEmpty ? nil : PhoneNumber(dial: dial.dial, number: newPhone),
            dateOfBirth: birthDate,
            nationalityID: nationality?.id,
            positionID: position?.id,
            avatar: photo
        )
    }

    /// Name, date of birth and nationality are required, as in the current app.
    @discardableResult
    func validate() -> Bool {
        var errors: [Field: String] = [:]
        if name.trimmingCharacters(in: .whitespaces).isEmpty {
            errors[.name] = String(localized: L10n.Profile.pleaseEnterName)
        }
        let newEmail = email.trimmingCharacters(in: .whitespaces)
        if !isEmailLocked, !newEmail.isEmpty, !Validation.isValidEmail(newEmail) {
            errors[.email] = String(localized: L10n.Auth.pleaseEnterValidEmail)
        }
        if birthDate == nil {
            errors[.dateOfBirth] = String(localized: L10n.Profile.pleaseEnterDate)
        }
        if nationality == nil {
            errors[.nationality] = String(localized: L10n.Profile.pleaseSelectNationality)
        }
        self.errors = errors
        return errors.isEmpty
    }

    /// No silent defaults: an unset nationality or position stays unset until the player picks one.
    /// (The current app pre-picked "Qatari", the first position and the first city, and saved them.)
    private func fill(from profile: PlayerProfile) {
        name = profile.fullName
        email = profile.email
        phone = profile.phone
        dial = CountryDialCodes.byDial(profile.dialCode) ?? CountryDialCodes.qatar
        birthDate = profile.birthDate
        nationality = profile.nationality.flatMap { current in nationalities.first { $0.id == current.id } }
            ?? profile.nationality
        position = profile.position.flatMap { current in positions.first { $0.id == current.id } } ?? profile.position
    }

    /// Server field errors go under their box; anything else is a toast.
    private func show(_ fieldErrors: [FieldError]) {
        let fields: [String: Field] = [
            "first_name": .name, "last_name": .name, "email": .email, "phone": .phone, "country_code": .phone,
            "date_of_birth": .dateOfBirth, "nationality": .nationality, "position": .position,
        ]
        var unplaced: [FieldError] = []
        for error in fieldErrors {
            if let field = fields[error.field] {
                errors[field] = error.message
            } else {
                unplaced.append(error)
            }
        }
        if !unplaced.isEmpty {
            toasts.show(.validation(unplaced))
        }
    }
}
