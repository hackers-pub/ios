import WebKit

@MainActor
enum HTMLWebViewLifecycle {
    static let messageHandlerNames = ["tapHandler", "linkPressHandler", "heightHandler"]

    static func dismantle(_ webView: WKWebView) {
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        webView.scrollView.delegate = nil

        let userContentController = webView.configuration.userContentController
        for name in messageHandlerNames {
            userContentController.removeScriptMessageHandler(forName: name)
        }
        userContentController.removeAllUserScripts()
    }
}
