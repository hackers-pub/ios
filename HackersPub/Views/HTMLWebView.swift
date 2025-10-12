import SwiftUI
import WebKit

#if os(macOS)
struct HTMLWebView: NSViewRepresentable {
    let html: String
    @Binding var height: CGFloat

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = context.coordinator
        webView.enclosingScrollView?.hasVerticalScroller = false
        webView.enclosingScrollView?.hasHorizontalScroller = false
        webView.enclosingScrollView?.isVerticallyResizable = false
        webView.enclosingScrollView?.isHorizontallyResizable = false
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let styledHTML = HTMLStyles.wrapHTML(html)
        webView.loadHTMLString(styledHTML, baseURL: nil)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: HTMLWebView

        init(_ parent: HTMLWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript("document.body.scrollHeight") { result, error in
                if let height = result as? CGFloat {
                    DispatchQueue.main.async {
                        self.parent.height = height
                    }
                }
            }
        }
    }
}
#else
struct HTMLWebView: UIViewRepresentable {
    let html: String
    @Binding var height: CGFloat
    var onTap: (() -> Void)?
    var navigationCoordinator: NavigationCoordinator?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(context.coordinator, name: "tapHandler")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = false

        // Disable pinch to zoom, hide scrollbars, and add tap detection
        let source = """
        var meta = document.createElement('meta');
        meta.name = 'viewport';
        meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
        document.getElementsByTagName('head')[0].appendChild(meta);

        // Hide scrollbars
        var style = document.createElement('style');
        style.textContent = 'body { overflow: hidden; } ::-webkit-scrollbar { display: none; }';
        document.getElementsByTagName('head')[0].appendChild(style);

        // Detect taps on non-link elements
        document.addEventListener('click', function(e) {
            // Check if the click is on a link or inside a link
            let target = e.target;
            while (target) {
                if (target.tagName === 'A') {
                    return; // Don't send tap message if clicking on a link
                }
                target = target.parentElement;
            }
            // Only send tap message if not clicking on a link
            window.webkit.messageHandlers.tapHandler.postMessage('tap');
            e.preventDefault();
        }, true);
        """
        let script = WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        configuration.userContentController.addUserScript(script)

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Generate CSS with current dynamic type size
        let bodyFont = UIFont.preferredFont(forTextStyle: .body)
        let css = HTMLStyles.generateCSS(fontSize: bodyFont.pointSize)
        let styledHTML = HTMLStyles.wrapHTML(html, css: css)
        webView.loadHTMLString(styledHTML, baseURL: nil)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: HTMLWebView

        init(_ parent: HTMLWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript("document.body.scrollHeight") { result, error in
                if let height = result as? CGFloat {
                    DispatchQueue.main.async {
                        self.parent.height = height
                    }
                }
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated {
                if let url = navigationAction.request.url {
                    // Check if this is a profile URL like https://hackers.pub/@username
                    if url.host == "hackers.pub" && url.path.hasPrefix("/@") {
                        let handle = String(url.path.dropFirst(2)) // Remove "/@"
                        if let coordinator = parent.navigationCoordinator {
                            DispatchQueue.main.async {
                                coordinator.navigateToProfile(handle: handle)
                            }
                        }
                    } else {
                        UIApplication.shared.open(url)
                    }
                }
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "tapHandler" {
                parent.onTap?()
            }
        }
    }
}
#endif
