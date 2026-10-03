import Foundation
import Testing
@testable import ChampzKit

@MainActor
struct OtpVerifyViewModelTests {
    private final class Captured: @unchecked Sendable {
        var signedIn: (AuthSession, AuthMode)?
    }

    private let identifier = AuthIdentifier.phone(countryCode: "+974", number: "55512345")

    private struct Harness {
        let viewModel: OtpVerifyViewModel
        let captured: Captured
        let toasts: ToastCenter
    }

    private func make(resendAfter: Int = 30, mode: AuthMode = .signIn, repo: FakeAuthRepository) -> Harness {
        let captured = Captured()
        let toasts = ToastCenter()
        let challenge = OtpChallenge(channel: .sms, sentTo: "+974 •••• 2345", expiresIn: 600, resendAfter: resendAfter)
        let viewModel = OtpVerifyViewModel(
            identifier: identifier,
            challenge: challenge,
            mode: mode,
            auth: repo,
            toasts: toasts
        ) {
            captured.signedIn = ($0, $1)
        }
        return Harness(viewModel: viewModel, captured: captured, toasts: toasts)
    }

    @Test func timerStartsFromServerValueAndBlocksResend() {
        let viewModel = make(resendAfter: 42, repo: FakeAuthRepository()).viewModel
        #expect(viewModel.resendSeconds == 42)
        #expect(viewModel.resendCountdownLabel == "0:42")
        #expect(!viewModel.canResend)
        viewModel.stopCountdown()
    }

    @Test func verifySuccessReportsModeToTheApp() async {
        let repo = FakeAuthRepository()
        let harness = make(mode: .signUp, repo: repo)
        let (viewModel, captured) = (harness.viewModel, harness.captured)
        viewModel.code = "123456"
        await viewModel.verify()
        #expect(captured.signedIn?.1 == .signUp)
        #expect(captured.signedIn?.0.user.id == PlayerID("7"))
        #expect(await repo.calls == [.verify(identifier, "123456")])
    }

    @Test func shortCodeIsRejectedLocally() async {
        let repo = FakeAuthRepository()
        let harness = make(repo: repo)
        let (viewModel, captured, toasts) = (harness.viewModel, harness.captured, harness.toasts)
        viewModel.code = "123"
        await viewModel.verify()
        #expect(captured.signedIn == nil)
        #expect(toasts.current?.kind == .error)
        #expect(await repo.calls.isEmpty)
        viewModel.stopCountdown()
    }

    @Test func invalidCodeClearsInputAndToasts() async {
        let repo = FakeAuthRepository()
        await repo.set(verify: .failure(.server(
            message: "The one-time password is invalid or has expired.",
            code: APIErrorCode.otpInvalid
        )))
        let harness = make(repo: repo)
        let (viewModel, captured, toasts) = (harness.viewModel, harness.captured, harness.toasts)
        viewModel.code = "000000"
        await viewModel.verify()
        #expect(captured.signedIn == nil)
        #expect(viewModel.code == "")
        #expect(toasts.current?.kind == .error)
        viewModel.stopCountdown()
    }

    @Test func resendRestartsTimerFromNewChallenge() async {
        let repo = FakeAuthRepository()
        await repo.set(challenge: .success(OtpChallenge(channel: .sms, sentTo: "x", expiresIn: 600, resendAfter: 60)))
        let harness = make(resendAfter: 0, repo: repo)
        let (viewModel, toasts) = (harness.viewModel, harness.toasts)
        #expect(viewModel.canResend)
        await viewModel.resend()
        #expect(viewModel.resendSeconds == 60)
        #expect(toasts.current?.kind == .success)
        #expect(await repo.calls == [.resend(identifier)])
        viewModel.stopCountdown()
    }

    @Test func cooldownFromServerSetsTheTimer() async {
        let repo = FakeAuthRepository()
        await repo.set(challenge: .failure(.rateLimited(code: APIErrorCode.otpCooldown, retryAfter: 25)))
        let harness = make(resendAfter: 0, repo: repo)
        let (viewModel, toasts) = (harness.viewModel, harness.toasts)
        await viewModel.resend()
        #expect(viewModel.resendSeconds == 25)
        #expect(toasts.current?.kind == .error)
        viewModel.stopCountdown()
    }
}
