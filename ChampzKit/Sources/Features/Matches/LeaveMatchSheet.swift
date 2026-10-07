import SwiftUI

/// "Why are you leaving?" — pick one reason, confirm. Reasons come from the server;
/// the legacy fallback list is used if that call failed.
struct LeaveMatchSheet: View {
    var title = L10n.Team.leaveMatch
    let reasons: [LeaveReason]
    let playerCount: Int
    let onLeave: (String) -> Void

    @State private var selected: String?
    @Environment(\.dismiss) private var dismiss

    private static let fallback = ["Change of plans", "Injury", "Personal Reason", "Found another game", "Other"]

    private var options: [String] {
        reasons.isEmpty ? Self.fallback : reasons.map(\.reason)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            Text(title)
                .font(AppFont.title2)
                .foregroundStyle(.ds.textPrimary)
            Text(L10n.Matches.leaveReasonPrompt)
                .font(AppFont.body)
                .foregroundStyle(.ds.textSecondary)
            VStack(spacing: Spacing.s) {
                ForEach(options, id: \.self) { option in
                    Button { selected = option } label: {
                        HStack {
                            Text(verbatim: option).font(AppFont.body).foregroundStyle(.ds.textPrimary)
                            Spacer()
                            Image(selected == option ? .checkCircle : .circle)
                                .foregroundStyle(selected == option ? Color.ds.brandPrimary : Color.ds
                                    .controlUnselected)
                        }
                        .padding(Spacing.l)
                        .background(
                            Color.ds.surfaceMuted,
                            in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer(minLength: 0)
            AppButton(title, style: .destructive) {
                if let selected {
                    onLeave(selected)
                }
            }
            .disabled(selected == nil)
        }
        .padding(Spacing.xl)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
