import Foundation
import Testing
import WebKit
@testable import ChampzKit

/// Runs the real bridge in a real WKWebView: the page posts a message from its own world,
/// the isolated-world script must forward it to the app.
@MainActor
struct ApplePayBridgeWebViewTests {
    private final class Collector: NSObject, WKScriptMessageHandler {
        var messages: [ApplePayMessage] = []
        func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage) {
            if let parsed = ApplePayMessage.parse(message.body) {
                messages.append(parsed)
            }
        }
    }

    @Test func pagePostMessageReachesTheAppThroughTheIsolatedWorld() async throws {
        let collector = Collector()
        let controller = WKUserContentController()
        controller.addUserScript(WKUserScript(
            source: ApplePayButton.bridge,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false,
            in: .defaultClient
        ))
        controller.add(collector, contentWorld: .defaultClient, name: ApplePayButton.handlerName)
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 300, height: 60), configuration: configuration)

        let page = """
        <html><body><script>
          setTimeout(function () {
            window.postMessage({ type: 'skipcash-fullscreen' }, '*');
            window.postMessage(JSON.stringify({ status: 'paid', orderId: 'pay1' }), '*');
          }, 50);
        </script></body></html>
        """
        webView.loadHTMLString(page, baseURL: URL(string: "https://sdk.skipcash.app"))

        for _ in 0 ..< 50 where collector.messages.isEmpty {
            try await Task.sleep(for: .milliseconds(100))
        }
        #expect(collector.messages == [.paid(orderId: "pay1")])
    }
}
