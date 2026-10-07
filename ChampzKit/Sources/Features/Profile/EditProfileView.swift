import SwiftUI

/// edit_profile_screen.dart: photo, then the ACCOUNT INFO card (name, email, phone,
/// date of birth, nationality, position) and Save Changes. Shown as a sheet.
public struct EditProfileView: View {
    @State var viewModel: EditProfileViewModel
    @State private var picking: Picking?

    private enum Picking: Identifiable {
        case birthDate, nationality, position
        var id: Self {
            self
        }
    }

    public init(viewModel: EditProfileViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        NavigationStack {
            LoadableView(viewModel.state, retry: { await viewModel.load() }) { profile in
                ScrollView {
                    VStack(spacing: Spacing.xxl) {
                        AvatarEditor(currentURL: profile.avatarUrl, name: profile.fullName, photo: viewModel.photo) {
                            viewModel.setPhoto($0)
                        }
                        accountInfo
                    }
                    .padding(Spacing.gutter)
                }
                .scrollDismissesKeyboard(.interactively)
                .safeAreaInset(edge: .bottom) {
                    AppButton(L10n.Profile.saveChanges, style: .primary, isLoading: viewModel.isSaving) {
                        Task { await viewModel.save() }
                    }
                    .padding(Spacing.gutter)
                    .background(Color.ds.backgroundMuted)
                }
            }
            .background(Color.ds.backgroundMuted)
            .navigationTitle(Text(L10n.Profile.myProfile))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: viewModel.close) { Image(.close) }
                }
            }
        }
        .sheet(item: $picking) { picker in
            switch picker {
            case .birthDate:
                BirthDateSheet(date: viewModel.birthDate) {
                    viewModel.birthDate = $0
                    viewModel.edited(.dateOfBirth)
                }
            case .nationality:
                SelectionSheet(
                    L10n.Profile.nationality,
                    items: viewModel.nationalities,
                    selection: viewModel.nationality,
                    searchPrompt: L10n.TransferMarket.searchForYourCountry,
                    label: \.label
                ) {
                    viewModel.nationality = $0
                    viewModel.edited(.nationality)
                }
            case .position:
                SelectionSheet(
                    L10n.Profile.selectYourPosition,
                    items: viewModel.positions,
                    selection: viewModel.position,
                    label: \.name
                ) {
                    viewModel.position = $0
                    viewModel.edited(.position)
                }
                .presentationDetents([.medium, .large])
            }
        }
        .task { await viewModel.load() }
    }

    private var accountInfo: some View {
        FormCard(title: L10n.Profile.accountInfo) {
            AppTextField(
                L10n.Profile.enterName,
                text: $viewModel.name,
                label: L10n.Profile.name,
                error: viewModel.errors[.name],
                contentType: .name,
                autocapitalization: .words
            )
            .onChange(of: viewModel.name) { viewModel.edited(.name) }
            AppTextField(
                L10n.Auth.enterEmail,
                text: $viewModel.email,
                label: L10n.Common.email,
                error: viewModel.errors[.email],
                keyboard: .emailAddress,
                contentType: .emailAddress,
                autocapitalization: .never
            )
            .disabled(viewModel.isEmailLocked)
            .onChange(of: viewModel.email) { viewModel.edited(.email) }
            AppTextField(
                L10n.SignUp.enterPhone,
                text: $viewModel.phone,
                label: L10n.SignUp.phoneNumber,
                error: viewModel.errors[.phone],
                keyboard: .phonePad,
                contentType: .telephoneNumber
            ) {
                CountryDialCodePicker(selection: $viewModel.dial)
            }
            .disabled(viewModel.isPhoneLocked)
            .onChange(of: viewModel.phone) { viewModel.edited(.phone) }
            PickerField(
                L10n.Profile.dateOfBirth,
                value: viewModel.birthDate.map(DateOfBirth.string(from:)),
                placeholder: "yyyy-MM-dd",
                error: viewModel.errors[.dateOfBirth]
            ) { picking = .birthDate }
            PickerField(
                L10n.Profile.nationality,
                value: viewModel.nationality?.label,
                placeholder: L10n.Profile.nationality,
                error: viewModel.errors[.nationality]
            ) { picking = .nationality }
            PickerField(
                L10n.Profile.position,
                value: viewModel.position?.name,
                placeholder: L10n.Profile.selectPosition,
                error: viewModel.errors[.position]
            ) { picking = .position }
        }
    }
}

/// Wheel date picker limited to the allowed ages, with a Select button.
private struct BirthDateSheet: View {
    let onSelect: (Date) -> Void
    @State private var date: Date
    @Environment(\.dismiss) private var dismiss
    private let range = DateOfBirth.allowedRange()

    init(date: Date?, onSelect: @escaping (Date) -> Void) {
        self.onSelect = onSelect
        let latest = range.upperBound
        _date = State(initialValue: min(date ?? latest, latest))
    }

    var body: some View {
        VStack(spacing: Spacing.l) {
            Text(L10n.Profile.dateOfBirth).font(AppFont.headline).foregroundStyle(.ds.textPrimary)
            DatePicker(selection: $date, in: range, displayedComponents: .date) { EmptyView() }
                .datePickerStyle(.wheel)
                .labelsHidden()
            AppButton(L10n.TransferMarket.select, style: .primary) {
                onSelect(date)
                dismiss()
            }
        }
        .padding(Spacing.gutter)
        .presentationDetents([.height(380)])
        .presentationDragIndicator(.visible)
    }
}
