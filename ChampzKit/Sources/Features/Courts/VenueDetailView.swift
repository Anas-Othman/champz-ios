import SwiftUI

/// The venue page: gallery, name and location, then BOOK COURT — day, start, duration, court —
/// and a sticky bar with the price and Book Now.
public struct VenueDetailView: View {
    @State var viewModel: VenueDetailViewModel

    public init(viewModel: VenueDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        LoadableView(
            viewModel.venue,
            retry: { await viewModel.load() },
            placeholder: { MatchDetailSkeleton() }
        ) { venue in
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        VenueGallery(venue: venue, share: viewModel.shareLink, onBack: viewModel.goBack)
                        VStack(alignment: .leading, spacing: Spacing.l) {
                            header(venue)
                            BookingPicker(viewModel: viewModel)
                        }
                        .padding(Spacing.gutter)
                    }
                    .padding(.bottom, 120)
                }
                .ignoresSafeArea(edges: .top)
                bookBar
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .background(Color.ds.backgroundMuted)
        .task { await viewModel.load() }
    }

    private func header(_ venue: Venue) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: Spacing.s) {
                Text(verbatim: venue.name).font(AppFont.screenTitle).foregroundStyle(.ds.textPrimary)
                DetailLine(icon: .brandMapPin, text: venue.location)
            }
            Spacer()
            Button(action: viewModel.openInfo) {
                Image(.info).font(.title3).foregroundStyle(.ds.brandPrimary)
            }
            .accessibilityLabel(Text(L10n.Courts.aboutVenue))
        }
    }

    /// Price for the chosen court, its duration, and Book Now.
    private var bookBar: some View {
        HStack(spacing: Spacing.m) {
            if let court = viewModel.court, let duration = viewModel.duration {
                VStack(alignment: .leading, spacing: 0) {
                    Text(verbatim: court.priceMoney.compact).font(AppFont.title2).foregroundStyle(.ds.brandPrimary)
                    Text(verbatim: L10n.Courts.minutes(duration)).font(AppFont.caption)
                        .foregroundStyle(.ds.textSecondary)
                }
            }
            AppButton(L10n.Court.bookNow, style: .primary, action: viewModel.book)
                .disabled(viewModel.start == nil || viewModel.duration == nil)
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.top, Spacing.l)
        .padding(.bottom, 34)
        .background(Color.ds.surface)
    }
}

/// Paged pictures with back and share buttons on top.
struct VenueGallery: View {
    let venue: Venue
    let share: URL
    let onBack: () -> Void

    var body: some View {
        TabView {
            if venue.gallery.isEmpty {
                Color.ds.separator
            }
            ForEach(venue.gallery, id: \.self) { url in
                RemoteImage(url: url)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: venue.gallery.count > 1 ? .automatic : .never))
        .frame(height: 280)
        .overlay(alignment: .top) {
            HStack {
                Button(action: onBack) { HeroButtonLabel(icon: .back) }
                Spacer()
                ShareLink(item: share) { HeroButtonLabel(icon: .brandShare) }
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.top, 62)
        }
    }
}

/// BOOK COURT: day strip, available-only switch, start times, durations, courts.
struct BookingPicker: View {
    let viewModel: VenueDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            Text(L10n.Court.bookCourt).font(AppFont.sectionTitle).foregroundStyle(.ds.textPrimary)
            days
            Toggle(isOn: Binding(get: { viewModel.availableOnly }, set: { viewModel.availableOnly = $0 })) {
                Text(L10n.Court.showAvailableSlotsOnly).font(AppFont.bodyEmphasis).foregroundStyle(.ds.textPrimary)
            }
            .tint(.ds.brandPrimary)
            starts
            if !viewModel.startDurations.isEmpty {
                label(L10n.Courts.selectDuration)
                PillRow(
                    items: viewModel.startDurations,
                    selected: viewModel.duration,
                    title: L10n.Courts.minutes
                ) { value in
                    Task { await viewModel.select(duration: value) }
                }
            }
            courts
        }
    }

    private var days: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.s) {
                ForEach(viewModel.days, id: \.self) { day in
                    DayCard(day: day, isSelected: day == viewModel.day) {
                        Task { await viewModel.select(day: day) }
                    }
                }
            }
            .padding(.horizontal, Spacing.gutter)
        }
        .padding(.horizontal, -Spacing.gutter)
    }

    @ViewBuilder
    private var starts: some View {
        label(L10n.Court.startTime)
        switch viewModel.grid {
        case .idle, .loading:
            ProgressView().frame(maxWidth: .infinity).padding(Spacing.l)
        case let .failed(error):
            ErrorStateView(error: error)
        case let .loaded(grid):
            if grid.isHoliday {
                note(L10n.Courts.closedForHoliday)
            } else if grid.starts.allSatisfy(\.isBooked) {
                note(L10n.Courts.noStartsLeft)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: Spacing.s)], spacing: Spacing.s) {
                    ForEach(grid.starts) { slot in
                        Pill(text: slot.label, isSelected: slot == viewModel.start, isEnabled: !slot.isBooked) {
                            Task { await viewModel.select(start: slot) }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var courts: some View {
        switch viewModel.courts {
        case .idle:
            EmptyView()
        case .loading:
            ProgressView().frame(maxWidth: .infinity).padding(Spacing.l)
        case let .failed(error):
            ErrorStateView(error: error)
        case let .loaded(courts):
            label(L10n.Courts.chooseCourt)
            if courts.isEmpty {
                note(L10n.Courts.noCourtsForWindow)
            }
            ForEach(courts) { court in
                CourtOption(court: court, isSelected: court == viewModel.court) { viewModel.select(court: court) }
            }
        }
    }

    private func label(_ text: LocalizedStringResource) -> some View {
        Text(text).font(AppFont.bodyEmphasis).foregroundStyle(.ds.textSecondary)
    }

    private func note(_ text: LocalizedStringResource) -> some View {
        Text(text).font(AppFont.detailBody).foregroundStyle(.ds.textTertiary)
    }
}
