@testable import HackersPub
import Testing
import UIKit
import WebKit

@MainActor
struct HTMLWebViewLifecycleTests {
    @Test
    func dismantleStopsTheViewAndReleasesDelegatesAndUserScripts() {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.addUserScript(
            WKUserScript(source: "window.__test = true;", injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        )
        let webView = WKWebView(frame: .zero, configuration: configuration)
        let delegate = WebViewDelegate()
        webView.navigationDelegate = delegate
        webView.uiDelegate = delegate
        webView.scrollView.delegate = delegate

        HTMLWebViewLifecycle.dismantle(webView)

        #expect(webView.navigationDelegate == nil)
        #expect(webView.uiDelegate == nil)
        #expect(webView.scrollView.delegate == nil)
        #expect(webView.configuration.userContentController.userScripts.isEmpty)
    }

    private final class WebViewDelegate: NSObject, WKNavigationDelegate, WKUIDelegate, UIScrollViewDelegate {}
}
