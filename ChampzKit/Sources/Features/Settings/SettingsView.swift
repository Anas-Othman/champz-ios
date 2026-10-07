import SwiftUI

/// "More": the settings hub, opened from the menu button on Home.
public struct SettingsView: View {
    @State var viewModel: SettingsViewModel

    public init(viewModel: SettingsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        List {
            if let balance = viewModel.balance {
                Section {
                    BalanceCard(balance: balance) { viewModel.open(.topUp) }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            }
            Section(header: Text(L10n.Home.application)) {
                row(L10n.History.title, icon: .trophy) { viewModel.open(.history) }
            }
            Section(header: Text(L10n.Home.account)) {
                row(L10n.Profile.myProfile, icon: .person, action: viewModel.editProfile)
                row(L10n.Settings.notificationSettings, icon: .notifications) { viewModel.open(.notificationSettings) }
                row(L10n.Payment.payments, icon: .wallet) { viewModel.open(.walletHistory) }
            }
            Section(header: Text(L10n.Home.support)) {
                row(L10n.Settings.faqs, icon: .info) { viewModel.open(.faq) }
                row(L10n.Settings.aboutChampz, icon: .football) { viewModel.open(.about) }
            }
            Section(header: Text(L10n.Home.legalInformation)) {
                row(L10n.SettingsScreen.privacyPolicy, icon: .lock) { viewModel.open(.legalPage(.privacyPolicy)) }
                row(L10n.Settings.termsOfService, icon: .document) { viewModel.open(.legalPage(.termsOfService)) }
            }
            #if DEBUG
                Section {
                    row(L10n.SettingsScreen.designSystem, icon: .settings) { viewModel.open(.designSystemCatalog) }
                }
            #endif
            Section {
                Button(role: .destructive) { viewModel.isLogOutConfirmPresented = true } label: {
                    Label { Text(L10n.SettingsScreen.logOut) } icon: { Image(.logOut) }
                }
                .disabled(viewModel.isLoggingOut)
                Button(role: .destructive) { viewModel.open(.deleteAccount) } label: {
                    Label { Text(L10n.Settings.deleteAccount) } icon: { Image(.delete) }
                }
            } footer: {
                Text(verbatim: viewModel.versionText).frame(maxWidth: .infinity).padding(.top, Spacing.l)
            }
        }
        .font(AppFont.bodyEmphasis)
        .navigationTitle(Text(L10n.SettingsScreen.title))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            Text(L10n.SettingsScreen.logOutConfirm),
            isPresented: $viewModel.isLogOutConfirmPresented,
            titleVisibility: .visible
        ) {
            Button(role: .destructive) { Task { await viewModel.logOut() } } label: { Text(L10n.SettingsScreen.logOut) }
        }
        .task { await viewModel.load() }
    }

    private func row(_ title: LocalizedStringResource, icon: AppIcon, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.m) {
                Image(icon).foregroundStyle(.ds.brandPrimary).frame(width: 24)
                Text(title).foregroundStyle(.ds.textPrimary)
                Spacer()
                Image(.chevronRight).font(.footnote).foregroundStyle(.ds.textTertiary)
            }
        }
    }
}

/// One toggle per notification category, saved as soon as it is flipped.
public struct NotificationSettingsView: View {
    @State var viewModel: NotificationSettingsViewModel

    public init(viewModel: NotificationSettingsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        LoadableView(viewModel.state, retry: { await viewModel.load() }) { preferences in
            List(preferences) { preference in
                Toggle(isOn: Binding(
                    get: { preference.isEnabled },
                    set: { value in Task { await viewModel.set(preference, enabled: value) } }
                )) {
                    Text(verbatim: preference.title).font(AppFont.bodyEmphasis)
                }
                .tint(.ds.brandPrimary)
                .disabled(viewModel.isSaving(preference))
            }
        }
        .navigationTitle(Text(L10n.Settings.notificationSettings))
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }
}

/// Privacy policy / terms of service.
public struct CmsPageView: View {
    @State var viewModel: CmsPageViewModel

    public init(viewModel: CmsPageViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        LoadableView(viewModel.state, retry: { await viewModel.load() }) { page in
            ScrollView {
                HTMLText(page.description)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Spacing.gutter)
            }
            .navigationTitle(Text(verbatim: page.name))
        }
        .background(Color.ds.background)
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }
}

/// FAQs: tap a question to open its answer.
public struct FaqView: View {
    @State var viewModel: FaqViewModel

    public init(viewModel: FaqViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        LoadableView(viewModel.state, isEmpty: \.isEmpty, retry: { await viewModel.load() }) { faqs in
            List(faqs) { faq in
                DisclosureGroup {
                    HTMLText(faq.description).padding(.vertical, Spacing.xs)
                } label: {
                    Text(verbatim: faq.title).font(AppFont.bodyEmphasis).foregroundStyle(.ds.textPrimary)
                }
                .tint(.ds.brandPrimary)
            }
        }
        .navigationTitle(Text(L10n.Settings.faqs))
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }
}

/// About Champz: the blurb, then email and WhatsApp when the company has them.
public struct AboutView: View {
    @State var viewModel: AboutViewModel
    @Environment(\.openURL) private var openURL

    public init(viewModel: AboutViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                Text(L10n.Settings.aboutChampzDescription).font(AppFont.detailBody).foregroundStyle(.ds.textSecondary)
                if let email = viewModel.emailURL {
                    ContactButton(icon: .email, title: L10n.SettingsScreen.email) { openURL(email) }
                }
                if let whatsApp = viewModel.whatsAppURL {
                    ContactButton(icon: .whatsApp, title: L10n.SettingsScreen.whatsApp) { openURL(whatsApp) }
                }
            }
            .padding(Spacing.gutter)
        }
        .background(Color.ds.background)
        .navigationTitle(Text(L10n.Settings.aboutChampz))
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }
}
