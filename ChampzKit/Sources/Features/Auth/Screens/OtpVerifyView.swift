import DesignSystem
import Domain
import Localization
import SwiftUI

/// The code screen: "Check your sms! We've sent…", six boxes, resend timer, Verify, terms.
struct OtpVerifyView: View {
    @State var viewModel: OtpVerifyViewModel

    var body: some View {
        VStack(spacing: Spacing.xl) {
            header
                .padding(.top, Spacing.xl)

            OTPCodeField(code: $viewModel.code, length: OtpVerifyViewModel.codeLength) { _ in
                Task { await viewModel.verify() }
            }
            .padding(.top, Spacing.l)

            resendButton

            Spacer()

            AppButton(L10n.Otp.verify, style: .primary, isLoading: viewModel.isVerifying) {
                Task { await viewModel.verify() }
            }
            .disabled(!viewModel.canVerify)

            TermsFooter()
        }
        .padding(.horizontal, Spacing.xl)
        .background(Color.ds.background)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { viewModel.stopCountdown() }
    }

    private var header: some View {
        VStack(spacing: Spacing.s) {
            Text(viewModel.challenge.channel == .email ? L10n.Auth.checkYourEmail : L10n.Auth.checkYourSms)
                .font(AppFont.body)
                .foregroundStyle(.ds.textSecondary)
            Text(verbatim: viewModel.challenge.sentTo)
                .font(AppFont.bodyEmphasis)
                .foregroundStyle(.ds.textPrimary)
        }
        .multilineTextAlignment(.center)
    }

    private var resendButton: some View {
        Button {
            Task { await viewModel.resend() }
        } label: {
            Group {
                if viewModel.resendSeconds > 0 {
                    Text(verbatim: L10n.Auth.requestNewCodeIn(viewModel.resendCountdownLabel))
                } else {
                    Text(L10n.Auth.requestNewCode)
                }
            }
            .font(AppFont.bodyEmphasis)
            .foregroundStyle(viewModel.canResend ? Color.ds.brandAccent : Color.ds.textTertiary)
            .frame(minHeight: ControlSize.minimumTapTarget)
            .overlay {
                if viewModel.isResending {
                    ProgressView()
                }
            }
        }
        .disabled(!viewModel.canResend)
        .monospacedDigit()
    }
}
