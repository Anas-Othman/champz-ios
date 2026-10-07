import SwiftUI
import WebKit

/// The Apple Pay button, as SkipCash renders it: a small web view showing their page.
/// Tapping it opens Apple's sheet; the page reports the outcome with `postMessage`.
///
/// The bridge script runs in WebKit's isolated client world (`.defaultClient`), not the page's.
/// WebKit turns Apple Pay off for pages whose own world has app-injected scripts; an isolated
/// world keeps Apple Pay available while still seeing the page's `message` events.
struct ApplePayButton: UIViewRepresentable {
    let session: PaymentSession
    let onMessage: (ApplePayMessage) -> Void

    static let handlerName = "skipcash"
    /// Forwards every `message` event to the app, as JSON text.
    static let bridge = """
    window.addEventListener('message', function (event) {
      try {
        var data = event && event.data;
        if (data == null) return;
        var payload = typeof data === 'string' ? data : JSON.stringify(data);
        window.webkit.messageHandlers.\(handlerName).postMessage(payload);
      } catch (e) {}
    });
    """

    func makeCoordinator() -> Coordinator {
        Coordinator(onMessage: onMessage)
    }

    func makeUIView(context: Context) -> WKWebView {
        let controller = WKUserContentController()
        controller.addUserScript(WKUserScript(
            source: Self.bridge,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false,
            in: .defaultClient
        ))
        controller.add(context.coordinator, contentWorld: .defaultClient, name: Self.handlerName)

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller
        configuration.allowsInlineMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        if let url = URL(string: session.checkoutUrl) {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateUIView(_: WKWebView, context _: Context) {}

    static func dismantleUIView(_ webView: WKWebView, coordinator _: Coordinator) {
        webView.configuration.userContentController.removeAllScriptMessageHandlers()
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        private let onMessage: (ApplePayMessage) -> Void
        private var last: ApplePayMessage?

        init(onMessage: @escaping (ApplePayMessage) -> Void) {
            self.onMessage = onMessage
        }

        func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let parsed = ApplePayMessage.parse(message.body), parsed != last else { return }
            last = parsed // the page may repeat itself; act once (current app does the same)
            onMessage(parsed)
        }
    }
}

/// Bottom bar while an Apple Pay session is live: SkipCash's button, or Retry once it expires.
struct ApplePayBar: View {
    let checkout: Checkout
    let session: PaymentSession

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Group {
                if session.isExpired(at: context.date) {
                    Button { checkout.applePayExpired() } label: {
                        Text(L10n.Checkout.retryApplePay)
                            .font(AppFont.buttonLarge)
                            .foregroundStyle(.ds.onApplePay)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Color.ds.applePayBackground, in: Capsule())
                    }
                } else {
                    ApplePayButton(session: session) { message in
                        Task { await checkout.applePayReported(message) }
                    }
                    .frame(height: 54)
                    .clipShape(Capsule())
                    .overlay {
                        if checkout.isSubmitting {
                            ProgressView()
                        }
                    }
                }
            }
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.vertical, Spacing.m)
        .background(Color.ds.backgroundMuted)
    }
}
