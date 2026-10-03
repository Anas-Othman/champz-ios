import SwiftUI

/// "Let's get started now!" — phone/email tabs, one field, Continue, terms.
struct IdentifierEntryView: View {
    @State var viewModel: IdentifierEntryViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                Text(L10n.Auth.letsGetStartedNow)
                    .font(AppFont.title1)
                    .foregroundStyle(.ds.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, Spacing.l)

                TextTabs(
                    selection: $viewModel.method,
                    tabs: [
                        TextTab(.phone, L10n.SignUp.phoneNumber),
                        TextTab(.email, L10n.Common.email),
                    ]
                )
                .padding(.top, Spacing.xl)

                field
                    .onChange(of: viewModel.method) { viewModel.inputChanged() }

                Text(viewModel.method == .email ? L10n.Auth.weWillSendOtp : L10n.Auth.weWillSendOtpPhone)
                    .font(AppFont.body)
                    .foregroundStyle(.ds.textSecondary)
                    .multilineTextAlignment(.center)

                AppButton(L10n.Common.continueKey, style: .primary, isLoading: viewModel.isSubmitting) {
                    Task { await viewModel.submit() }
                }
                .padding(.top, Spacing.l)

                TermsFooter()
            }
            .padding(.horizontal, Spacing.xl)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.ds.background)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var field: some View {
        switch viewModel.method {
        case .phone:
            AppTextField(
                L10n.ResetPassword.enterPhoneNumber,
                text: $viewModel.phoneNumber,
                error: viewModel.fieldError,
                keyboard: .phonePad,
                contentType: .telephoneNumber
            ) {
                CountryDialCodePicker(selection: $viewModel.country)
            }
            .onChange(of: viewModel.phoneNumber) { viewModel.inputChanged() }
        case .email:
            AppTextField(
                L10n.Auth.enterEmail,
                text: $viewModel.email,
                error: viewModel.fieldError,
                keyboard: .emailAddress,
                contentType: .emailAddress,
                autocapitalization: .never
            )
            .onChange(of: viewModel.email) { viewModel.inputChanged() }
        }
    }
}

/// "By clicking continue you agree to our Terms & Conditions" with a tappable link.
struct TermsFooter: View {
    private static let termsURL = URL(string: "https://champz.me/terms-of-service/")

    var body: some View {
        VStack(spacing: Spacing.xxs) {
            Text(L10n.Auth.byClickingContinue)
                .foregroundStyle(.ds.textSecondary)
            if let url = Self.termsURL {
                Link(destination: url) {
                    Text(L10n.Auth.termsAndConditions)
                        .foregroundStyle(.ds.brandAccent)
                        .underline()
                }
            }
        }
        .font(AppFont.caption)
        .multilineTextAlignment(.center)
        .padding(.vertical, Spacing.l)
    }
}
