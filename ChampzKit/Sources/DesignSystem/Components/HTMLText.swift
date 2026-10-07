import SwiftUI
import UIKit

/// Server HTML (CMS pages, policies) as styled text: paragraphs, headings, lists, links.
/// The text takes the app's body font and colour; links stay tappable.
public struct HTMLText: View {
    private let html: String
    @State private var text: AttributedString?

    public init(_ html: String) {
        self.html = html
    }

    public var body: some View {
        Group {
            if let text {
                Text(text)
            } else {
                Text(verbatim: html.strippingHTMLTags)
            }
        }
        .font(AppFont.detailBody)
        .foregroundStyle(.ds.textPrimary)
        .tint(.ds.brandPrimary)
        .textSelection(.enabled)
        .task(id: html) { text = Self.render(html) }
    }

    /// WebKit's HTML importer; it must run on the main thread.
    @MainActor
    static func render(_ html: String) -> AttributedString? {
        guard let data = html.data(using: .utf8),
              let imported = try? NSMutableAttributedString(
                  data: data,
                  options: [
                      .documentType: NSAttributedString.DocumentType.html,
                      .characterEncoding: String.Encoding.utf8.rawValue,
                  ],
                  documentAttributes: nil
              )
        else { return nil }
        // Keep the structure (bold, links, lists) but drop the importer's Times font and black colour.
        let whole = NSRange(location: 0, length: imported.length)
        imported.removeAttribute(.foregroundColor, range: whole)
        imported.enumerateAttribute(.font, in: whole) { value, range, _ in
            guard let font = value as? UIFont else { return }
            let traits = font.fontDescriptor.symbolicTraits
            imported.removeAttribute(.font, range: range)
            if traits.contains(.traitBold) {
                imported.addAttribute(
                    .inlinePresentationIntent,
                    value: InlinePresentationIntent.stronglyEmphasized.rawValue,
                    range: range
                )
            }
        }
        let trimmed = imported.string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed
            .isEmpty ? nil : (try? AttributedString(imported, including: \.uiKit)) ?? AttributedString(imported)
    }
}

extension String {
    /// Fallback while (or if) the HTML import is not available.
    var strippingHTMLTags: String {
        replacingOccurrences(of: "<br\\s*/?>|</p>", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
