import SwiftUI

/// The start page: headline, Create Account, Login. No logic, so no view model.
struct WelcomeView: View {
    let onCreateAccount: () -> Void
    let onLogin: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            Spacer()
            Text(L10n.Onboarding.welcomeToChampz)
                .font(AppFont.display)
                .foregroundStyle(.ds.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            AppButton(L10n.Auth.createAccount, style: .primary, action: onCreateAccount)
            Button(action: onLogin) {
                Text(L10n.Auth.login)
                    .font(AppFont.bodyEmphasis)
                    .foregroundStyle(.ds.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: ControlSize.minimumTapTarget)
            }
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.bottom, Spacing.l)
        .background(Color.ds.background)
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview {
    NavigationStack { WelcomeView(onCreateAccount: {}, onLogin: {}) }
}
