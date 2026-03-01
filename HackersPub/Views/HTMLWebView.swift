import SwiftUI
import WebKit

// MARK: - Content Hash for Deduplication

/// Generates a stable hash key from all inputs that affect rendered output,
/// used to skip redundant `loadHTMLString` calls and cache computed heights.
struct HTMLContentKey: Equatable, Hashable {
    let html: String
    let fontName: String
    let sizeMultiplier: Double
    let useSystemDynamicType: Bool
    let dynamicTypeSize: DynamicTypeSize
    let availableWidth: CGFloat
}

// MARK: - Height Cache

/// Thread-safe, in-memory cache mapping content keys to measured heights.
/// Avoids repeated `evaluateJavaScript("document.body.scrollHeight")` calls
/// for content that has already been laid out.
final class HTMLHeightCache: @unchecked Sendable {
    static let shared = HTMLHeightCache()

    private let lock = NSLock()
    private var store: [HTMLContentKey: CGFloat] = [:]
    private let maxEntries = 200

    func height(for key: HTMLContentKey) -> CGFloat? {
        lock.lock()
        defer { lock.unlock() }
        return store[key]
    }

    func setHeight(_ height: CGFloat, for key: HTMLContentKey) {
        lock.lock()
        defer { lock.unlock() }
        if store.count >= maxEntries {
            store.removeAll(keepingCapacity: true)
        }
        store[key] = height
    }
}

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

        func updateNSView(_ webView: WKWebView, context _: Context) {
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

            func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
                webView.evaluateJavaScript("document.body.scrollHeight") { result, _ in
                    if let height = result as? CGFloat {
                        DispatchQueue.main.async {
                            withAnimation(.easeOut(duration: 0.25)) {
                                self.parent.height = height
                            }
                        }
                    }
                }
            }
        }
    }
#else
    struct HTMLWebView: UIViewRepresentable {
        private enum InteractionTiming {
            static let pressToTapThresholdMs = 450
            static let suppressClickAfterContextMenuMs = 800
            static let ignoreTapAfterMenuOpen: TimeInterval = 0.75
            static let ignoreTapAfterMenuEnd: TimeInterval = 0.25
        }

        let html: String
        @Binding var height: CGFloat
        var onTap: (() -> Void)?
        var authManager: AuthManager?
        var navigationCoordinator: NavigationCoordinator?
        var suppressLongPressInteractions: Bool = false
        var sneakPeekPostId: String?
        @Environment(\.dynamicTypeSize) private var dynamicTypeSize
        @ObservedObject private var fontSettings = FontSettingsManager.shared

        // MARK: - UIViewRepresentable

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

            var pressStartTimestamp = 0;
            var ignoreClickUntil = 0;
            function markPressStart() {
                pressStartTimestamp = Date.now();
            }
            document.addEventListener('touchstart', markPressStart, true);
            document.addEventListener('pointerdown', markPressStart, true);
            document.addEventListener('mousedown', markPressStart, true);

            // Detect taps on non-link elements
            document.addEventListener('click', function(e) {
                if (Date.now() < ignoreClickUntil) {
                    return;
                }
                if (pressStartTimestamp > 0 && Date.now() - pressStartTimestamp > \(InteractionTiming.pressToTapThresholdMs)) {
                    return;
                }
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
            \(suppressLongPressInteractions ? """
            document.addEventListener('contextmenu', function(e) {
                ignoreClickUntil = Date.now() + \(InteractionTiming.suppressClickAfterContextMenuMs);
                e.preventDefault();
            }, true);
            document.addEventListener('selectstart', function(e) {
                e.preventDefault();
            }, true);
            """ : "")
            """
            let script = WKUserScript(
                source: source,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true
            )
            configuration.userContentController.addUserScript(script)

            return webView
        }

        func updateUIView(_ webView: WKWebView, context: Context) {
            // Update coordinator reference
            context.coordinator.parent = self
            context.coordinator.attachContextMenuInteractionIfNeeded(to: webView)

            // Build a content key that captures every variable affecting the rendered output
            let contentKey = HTMLContentKey(
                html: html,
                fontName: fontSettings.selectedFontName,
                sizeMultiplier: fontSettings.fontSizeMultiplier,
                useSystemDynamicType: fontSettings.useSystemDynamicType,
                dynamicTypeSize: dynamicTypeSize,
                availableWidth: webView.bounds.width
            )

            // Skip reload if nothing relevant changed (same html + same style + same size)
            guard contentKey != context.coordinator.lastContentKey else { return }
            context.coordinator.lastContentKey = contentKey

            // If we already measured the height for this exact content, reuse it immediately
            if let cached = HTMLHeightCache.shared.height(for: contentKey) {
                if height != cached {
                    DispatchQueue.main.async {
                        guard context.coordinator.lastContentKey == contentKey else { return }
                        if context.coordinator.parent.height != cached {
                            context.coordinator.parent.height = cached
                        }
                    }
                }
            }

            // Generate CSS once per settings change, not per cell
            let fontSize = fontSettings.scaledSize(for: .body)
            var css = HTMLStyles.generateCSS(fontSize: fontSize, fontFamily: fontSettings.cssFontFamily)
            if suppressLongPressInteractions {
                css += """
                
                body, body * {
                    -webkit-user-select: none !important;
                    user-select: none !important;
                    -webkit-touch-callout: none !important;
                }
                """
            }
            let styledHTML = HTMLStyles.wrapHTML(html, css: css)

            // Capture the content key for this navigation so didFinish can verify it.
            context.coordinator.pendingContentKey = contentKey
            webView.loadHTMLString(styledHTML, baseURL: nil)
        }

        func makeCoordinator() -> Coordinator {
            Coordinator(self)
        }

        // MARK: - Coordinator

        class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler, UIContextMenuInteractionDelegate {
            var parent: HTMLWebView
            var lastContentKey: HTMLContentKey?
            /// Content key captured at navigation start, used to verify
            /// that the finished navigation still matches the current content.
            var pendingContentKey: HTMLContentKey?
            var contextMenuInteraction: UIContextMenuInteraction?
            private weak var contextMenuHostView: UIView?
            private var ignoreTapUntil: Date = .distantPast

            init(_ parent: HTMLWebView) {
                self.parent = parent
            }

            func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
                attachContextMenuInteractionIfNeeded(to: webView)
                // Verify the finished navigation matches the most recently requested content.
                // If a newer load was initiated while this one was in-flight, discard the result
                // to prevent caching a height under the wrong content key.
                guard let pending = pendingContentKey, pending == lastContentKey else { return }

                webView.evaluateJavaScript("document.body.scrollHeight") { result, _ in
                    if let height = result as? CGFloat {
                        DispatchQueue.main.async {
                            // Re-check after the async gap to avoid stale writes.
                            guard let key = self.lastContentKey, key == pending else { return }
                            HTMLHeightCache.shared.setHeight(height, for: key)
                            self.parent.height = height
                        }
                    }
                }
            }

            func webView(
                _: WKWebView,
                decidePolicyFor navigationAction: WKNavigationAction,
                decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
            ) {
                if navigationAction.navigationType == .linkActivated {
                    if let url = navigationAction.request.url {
                        // Check if this is a profile URL like https://hackers.pub/@username
                        if url.host == "hackers.pub", url.path.hasPrefix("/@") {
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

            func userContentController(
                _: WKUserContentController,
                didReceive message: WKScriptMessage
            ) {
                if message.name == "tapHandler" {
                    guard Date() >= ignoreTapUntil else { return }
                    parent.onTap?()
                }
            }

            func contextMenuInteraction(
                _: UIContextMenuInteraction,
                configurationForMenuAtLocation _: CGPoint
            ) -> UIContextMenuConfiguration? {
                guard parent.sneakPeekPostId != nil else { return nil }
                ignoreTapUntil = Date().addingTimeInterval(InteractionTiming.ignoreTapAfterMenuOpen)

                return UIContextMenuConfiguration(
                    identifier: nil,
                    previewProvider: { [weak self] in
                        guard let self, let postId = self.parent.sneakPeekPostId else { return nil }
                        return self.makePostPreviewController(postId: postId)
                    },
                    actionProvider: { _ in
                        UIMenu(children: [])
                    }
                )
            }

            func contextMenuInteraction(
                _: UIContextMenuInteraction,
                willEndFor _: UIContextMenuConfiguration,
                animator _: UIContextMenuInteractionAnimating?
            ) {
                ignoreTapUntil = Date().addingTimeInterval(InteractionTiming.ignoreTapAfterMenuEnd)
            }

            private func makePostPreviewController(postId: String) -> UIViewController {
                let basePreview = AnyView(
                    PostDetailView(postId: postId)
                        .environmentObject(FontSettingsManager.shared)
                )
                let finalPreview = injectPreviewEnvironment(into: basePreview)

                let controller = UIHostingController(rootView: finalPreview)
                controller.view.backgroundColor = .systemBackground
                return controller
            }

            private func injectPreviewEnvironment(into view: AnyView) -> AnyView {
                var result = view
                if let authManager = parent.authManager {
                    result = AnyView(result.environment(authManager))
                }
                if let navigationCoordinator = parent.navigationCoordinator {
                    result = AnyView(result.environment(navigationCoordinator))
                }
                return result
            }

            func attachContextMenuInteractionIfNeeded(to webView: WKWebView) {
                guard parent.sneakPeekPostId != nil else {
                    if let interaction = contextMenuInteraction {
                        contextMenuHostView?.removeInteraction(interaction)
                    }
                    contextMenuHostView = nil
                    return
                }

                let contentView = webView.scrollView.subviews.first { subview in
                    NSStringFromClass(type(of: subview)).contains("WKContent")
                }
                let targetView = contentView ?? webView.scrollView

                if contextMenuHostView === targetView {
                    return
                }

                let interaction = contextMenuInteraction ?? UIContextMenuInteraction(delegate: self)
                contextMenuHostView?.removeInteraction(interaction)
                targetView.addInteraction(interaction)
                contextMenuInteraction = interaction
                contextMenuHostView = targetView
            }
        }
    }
#endif
