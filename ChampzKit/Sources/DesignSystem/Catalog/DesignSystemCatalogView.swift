import Core
import Localization
import SwiftUI

/// Debug-only gallery of every token and component, so the look is reviewed in one place.
/// String literals are allowed here (lint exclusion) — it is not user-facing.
public struct DesignSystemCatalogView: View {
    public init() {}

    public var body: some View {
        List {
            Section("Typography") {
                Text("Display 36").font(AppFont.display)
                Text("Title 1 · 28").font(AppFont.title1)
                Text("Title 2 · 20").font(AppFont.title2)
                Text("Headline · 18").font(AppFont.headline)
                Text("Body large · 16").font(AppFont.bodyLarge)
                Text("Body · 14").font(AppFont.body)
                Text("Body emphasis · 14").font(AppFont.bodyEmphasis)
                Text("Caption · 13").font(AppFont.caption)
                Text("Caption small · 12").font(AppFont.captionSmall)
            }
            Section("Colors") {
                swatch("brandPrimary", .ds.brandPrimary)
                swatch("brandAccent", .ds.brandAccent)
                swatch("textPrimary", .ds.textPrimary)
                swatch("textSecondary", .ds.textSecondary)
                swatch("textTertiary", .ds.textTertiary)
                swatch("border", .ds.border)
                swatch("backgroundMuted", .ds.backgroundMuted)
                swatch("statusSuccess", .ds.statusSuccess)
                swatch("statusError", .ds.statusError)
                swatch("statusWarning", .ds.statusWarning)
                swatch("statusInfo", .ds.statusInfo)
            }
            Section("Buttons") {
                AppButton("Primary", style: .primary) {}
                AppButton("Loading", style: .primary, isLoading: true) {}
                AppButton("Secondary", style: .secondary, icon: .wallet) {}
                AppButton("Destructive", style: .destructive) {}
                AppButton("Text", style: .text) {}
            }
            Section("Cards") {
                SectionHeader("Section header", actionTitle: "Action") {}
                AppCard { Text("Card content").font(AppFont.body) }
            }
            Section("States") {
                ErrorStateView(error: .offline) {}.frame(height: 240)
                ErrorStateView(error: .server(message: "The venue is closed on Fridays.", code: nil)).frame(height: 200)
                EmptyStateView(title: L10n.Errors.emptyTitle).frame(height: 160)
                ListSkeleton(rows: 2)
            }
            Section("Icons") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6)) {
                    ForEach(AppIcon.allCases, id: \.rawValue) { icon in
                        Image(icon).font(.title3).foregroundStyle(.ds.textSecondary).frame(height: 36)
                    }
                }
            }
        }
        .navigationTitle("Design system")
    }

    private func swatch(_ name: String, _ color: Color) -> some View {
        HStack {
            RoundedRectangle(cornerRadius: Radius.s).fill(color).frame(width: 36, height: 36)
                .overlay(RoundedRectangle(cornerRadius: Radius.s).strokeBorder(Color.ds.border))
            Text(name).font(AppFont.body)
        }
    }
}

#Preview {
    NavigationStack { DesignSystemCatalogView() }
}
