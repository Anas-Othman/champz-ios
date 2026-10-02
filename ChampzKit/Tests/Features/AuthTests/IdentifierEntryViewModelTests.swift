import Core
import DesignSystem
import Domain
import Foundation
import Testing
@testable import AuthFeature

@MainActor
struct IdentifierEntryViewModelTests {
    private final class Captured: @unchecked Sendable {
        var challenge: (AuthIdentifier, OtpChallenge)?
    }

    private struct Harness {
        let viewModel: IdentifierEntryViewModel
        let captured: Captured
        let toasts: ToastCenter
    }

    private func make(mode: AuthMode = .signIn, repo: FakeAuthRepository) -> Harness {
        let captured = Captured()
        let toasts = ToastCenter()
        let viewModel = IdentifierEntryViewModel(mode: mode, auth: repo, toasts: toasts) {
            captured.challenge = ($0, $1)
        }
        return Harness(viewModel: viewModel, captured: captured, toasts: toasts)
    }

    @Test func phoneNeedsSixDigitsAndKeepsOnlyDigits() async {
        let repo = FakeAuthRepository()
        let harness = make(repo: repo)
        let (viewModel, captured) = (harness.viewModel, harness.captured)
        viewModel.phoneNumber = "5551"
        await viewModel.submit()
        #expect(viewModel.fieldError != nil)
        #expect(captured.challenge == nil)
        #expect(await repo.calls.isEmpty)

        viewModel.inputChanged()
        viewModel.phoneNumber = "555-123 45"
        await viewModel.submit()
        #expect(viewModel.fieldError == nil)
        #expect(captured.challenge?.0 == .phone(countryCode: "+974", number: "55512345"))
        #expect(await repo.calls == [.signIn(.phone(countryCode: "+974", number: "55512345"))])
    }

    @Test func emailIsValidatedTrimmedAndLowercased() async {
        let repo = FakeAuthRepository()
        let harness = make(mode: .signUp, repo: repo)
        let (viewModel, captured) = (harness.viewModel, harness.captured)
        viewModel.method = .email
        viewModel.email = "not-an-email"
        await viewModel.submit()
        #expect(viewModel.fieldError != nil)

        viewModel.email = "  Anas@Champz.ME \n"
        await viewModel.submit()
        #expect(captured.challenge?.0 == .email("anas@champz.me"))
        #expect(await repo.calls == [.signUp(.email("anas@champz.me"))])
    }

    @Test func serverErrorBecomesToastNotNavigation() async {
        let repo = FakeAuthRepository()
        await repo.set(challenge: .failure(.rateLimited(code: APIErrorCode.otpCooldown, retryAfter: 40)))
        let harness = make(repo: repo)
        let (viewModel, captured, toasts) = (harness.viewModel, harness.captured, harness.toasts)
        viewModel.phoneNumber = "55512345"
        await viewModel.submit()
        #expect(captured.challenge == nil)
        #expect(toasts.current?.kind == .error)
        #expect(!viewModel.isSubmitting)
    }

    @Test func countryCodeTravelsWithThePhone() async {
        let repo = FakeAuthRepository()
        let harness = make(repo: repo)
        let (viewModel, captured) = (harness.viewModel, harness.captured)
        viewModel.country = CountryDialCode(code: "EG", dial: "+20")
        viewModel.phoneNumber = "1001234567"
        await viewModel.submit()
        #expect(captured.challenge?.0 == .phone(countryCode: "+20", number: "1001234567"))
    }
}
