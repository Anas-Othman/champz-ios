import Foundation
import SwiftUI

/// A country's dialling prefix. Code + dial come from the bundled dataset; the display
/// name comes from the user's locale, so it is localised for free.
public struct CountryDialCode: Hashable, Identifiable, Sendable {
    public let code: String
    public let dial: String

    public init(code: String, dial: String) {
        self.code = code
        self.dial = dial
    }

    public var id: String {
        code
    }

    public var name: String {
        Locale.current.localizedString(forRegionCode: code) ?? code
    }

    /// Regional-indicator flag emoji built from the ISO code.
    public var flag: String {
        code.unicodeScalars.compactMap { UnicodeScalar(127_397 + $0.value) }.map(String.init).joined()
    }
}

public enum CountryDialCodes {
    /// Every country, sorted by localised name. Loaded once from `CountryDialCodes.json`.
    public static let all: [CountryDialCode] = {
        guard let url = Bundle.module.url(forResource: "CountryDialCodes", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let rows = try? JSONDecoder().decode([Row].self, from: data)
        else {
            Log.app.error("CountryDialCodes.json missing or malformed")
            return [qatar]
        }
        return rows.map { CountryDialCode(code: $0.code, dial: $0.dial) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }()

    public static let qatar = CountryDialCode(code: "QA", dial: "+974")

    public static func byDial(_ dial: String) -> CountryDialCode? {
        all.first { $0.dial == dial }
    }

    private struct Row: Decodable {
        let code: String
        let dial: String
    }
}

/// Compact "🇶🇦 +974" button that opens a searchable country list.
public struct CountryDialCodePicker: View {
    @Binding private var selection: CountryDialCode
    @State private var isPresented = false

    public init(selection: Binding<CountryDialCode>) {
        _selection = selection
    }

    public var body: some View {
        Button {
            isPresented = true
        } label: {
            HStack(spacing: Spacing.xs) {
                Text(verbatim: selection.flag)
                Text(verbatim: selection.dial)
                    .font(AppFont.bodyLarge)
                    .foregroundStyle(.ds.textPrimary)
                Image(.chevronDown)
                    .font(.caption)
                    .foregroundStyle(.ds.textTertiary)
            }
        }
        .accessibilityLabel(Text(verbatim: "\(selection.name) \(selection.dial)"))
        .sheet(isPresented: $isPresented) {
            CountryDialCodeList(selection: $selection)
        }
    }
}

private struct CountryDialCodeList: View {
    @Binding var selection: CountryDialCode
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var results: [CountryDialCode] {
        guard !query.isEmpty else { return CountryDialCodes.all }
        return CountryDialCodes.all.filter {
            $0.name.localizedCaseInsensitiveContains(query) || $0.dial.contains(query) || $0.code
                .localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            List(results) { country in
                Button {
                    selection = country
                    dismiss()
                } label: {
                    HStack {
                        Text(verbatim: country.flag)
                        Text(verbatim: country.name)
                            .font(AppFont.body)
                            .foregroundStyle(.ds.textPrimary)
                        Spacer()
                        Text(verbatim: country.dial)
                            .font(AppFont.body)
                            .foregroundStyle(.ds.textSecondary)
                        if country == selection {
                            Image(.check).foregroundStyle(.ds.brandPrimary)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .searchable(text: $query)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(.close) }
                }
            }
        }
        .presentationDetents([.large])
    }
}

#Preview("Country picker") {
    @Previewable @State var selection = CountryDialCodes.qatar
    CountryDialCodePicker(selection: $selection).padding()
}
