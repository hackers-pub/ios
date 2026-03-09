import SwiftUI
import WebKit
import SafariServices
@preconcurrency import Apollo

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
            static let linkPressFallbackWindow: TimeInterval = 4.0
        }

        private enum SneakPeekPreviewLayout {
            static let height: CGFloat = 560

            static var width: CGFloat {
                let screenWidth = UIScreen.main.bounds.width
                return min(380, max(280, screenWidth - 24))
            }
        }

        let html: String
        @Binding var height: CGFloat
        var onTap: (() -> Void)?
        var authManager: AuthManager?
        var navigationCoordinator: NavigationCoordinator?
        var externalURLRouter: ExternalURLRouter?
        var suppressLongPressInteractions: Bool = false
        var sneakPeekPostId: String?
        var sneakPeekActorHandle: String?
        var sneakPeekShareURL: URL?
        var onLinkPressStateChange: ((URL?) -> Void)?
        @Environment(\.dynamicTypeSize) private var dynamicTypeSize
        @ObservedObject private var fontSettings = FontSettingsManager.shared

        // MARK: - UIViewRepresentable

        func makeUIView(context: Context) -> WKWebView {
            let configuration = WKWebViewConfiguration()
            configuration.userContentController.add(context.coordinator, name: "tapHandler")
            configuration.userContentController.add(context.coordinator, name: "linkPressHandler")
            configuration.userContentController.add(context.coordinator, name: "heightHandler")

            let webView = WKWebView(frame: .zero, configuration: configuration)
            webView.isOpaque = false
            webView.backgroundColor = .clear
            webView.navigationDelegate = context.coordinator
            webView.uiDelegate = context.coordinator
            webView.scrollView.isScrollEnabled = false
            webView.scrollView.delegate = context.coordinator
            webView.scrollView.bounces = false
            webView.scrollView.alwaysBounceVertical = false
            webView.scrollView.alwaysBounceHorizontal = false
            webView.scrollView.contentInset = .zero
            webView.scrollView.scrollIndicatorInsets = .zero
            webView.scrollView.contentInsetAdjustmentBehavior = .never
            webView.scrollView.setContentOffset(.zero, animated: false)
            context.coordinator.webView = webView

            // Replace WKWebView's built-in link-only context menu with our own
            // UIContextMenuInteraction that handles both links AND non-link post preview.
            for interaction in webView.interactions where interaction is UIContextMenuInteraction {
                webView.removeInteraction(interaction)
            }
            let contextMenuInteraction = UIContextMenuInteraction(delegate: context.coordinator)
            webView.addInteraction(contextMenuInteraction)

            // Disable pinch to zoom, hide scrollbars, and add tap detection
            let source = """
            var meta = document.createElement('meta');
            meta.name = 'viewport';
            meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
            document.getElementsByTagName('head')[0].appendChild(meta);

            // Hide scrollbars without forcing body clipping.
            var style = document.createElement('style');
            style.textContent = '::-webkit-scrollbar { display: none; }';
            document.getElementsByTagName('head')[0].appendChild(style);

            function computedDocumentHeight() {
                var body = document.body;
                var contentRoot = document.getElementById('content-root');
                var bodyStyle = body ? window.getComputedStyle(body) : null;
                var bodyPaddingTop = bodyStyle ? parseFloat(bodyStyle.paddingTop || '0') : 0;
                var bodyPaddingBottom = bodyStyle ? parseFloat(bodyStyle.paddingBottom || '0') : 0;
                if (contentRoot) {
                    var contentRect = contentRoot.getBoundingClientRect();
                    return Math.ceil(contentRect.height + bodyPaddingTop + bodyPaddingBottom);
                }
                var bodyRect = body ? body.getBoundingClientRect() : null;
                return Math.ceil(Math.max(
                    body ? body.scrollHeight : 0,
                    body ? body.offsetHeight : 0,
                    bodyRect ? bodyRect.height : 0
                ));
            }

            var pendingHeightFrame = false;
            function reportHeightSoon() {
                if (pendingHeightFrame) {
                    return;
                }
                pendingHeightFrame = true;
                requestAnimationFrame(function() {
                    pendingHeightFrame = false;
                    window.webkit.messageHandlers.heightHandler.postMessage(computedDocumentHeight());
                });
            }

            function resetScrollPosition() {
                window.scrollTo(0, 0);
                if (document.documentElement) {
                    document.documentElement.scrollTop = 0;
                }
                if (document.body) {
                    document.body.scrollTop = 0;
                }
            }

            var pressStartTimestamp = 0;
            var ignoreClickUntil = 0;
            function closestAnchor(node) {
                var current = node;
                while (current) {
                    if (current.tagName === 'A') {
                        return current;
                    }
                    current = current.parentElement;
                }
                return null;
            }
            function markPressStart(event) {
                pressStartTimestamp = Date.now();
                var anchor = closestAnchor(event.target);
                if (anchor && anchor.href) {
                    window.webkit.messageHandlers.linkPressHandler.postMessage(encodeURI(anchor.href));
                } else {
                    window.webkit.messageHandlers.linkPressHandler.postMessage("");
                }
            }
            function isInsideLink(node) {
                return closestAnchor(node) !== null;
            }
            document.addEventListener('touchstart', markPressStart, true);
            document.addEventListener('pointerdown', markPressStart, true);
            document.addEventListener('mousedown', markPressStart, true);
            document.addEventListener('DOMContentLoaded', function() { resetScrollPosition(); reportHeightSoon(); }, true);
            window.addEventListener('load', function() { resetScrollPosition(); reportHeightSoon(); }, true);
            window.addEventListener('resize', reportHeightSoon, true);

            var observer = new MutationObserver(function() {
                reportHeightSoon();
            });
            observer.observe(document.documentElement || document.body, {
                childList: true,
                subtree: true,
                attributes: true,
                characterData: true
            });

            function bindImageHeightListeners(root) {
                var images = (root || document).querySelectorAll ? (root || document).querySelectorAll('img') : [];
                for (var i = 0; i < images.length; i++) {
                    var img = images[i];
                    if (img.__heightListenerBound) {
                        continue;
                    }
                    img.__heightListenerBound = true;
                    img.addEventListener('load', reportHeightSoon, true);
                    img.addEventListener('error', reportHeightSoon, true);
                }
            }
            bindImageHeightListeners(document);
            document.addEventListener('DOMNodeInserted', function(e) {
                bindImageHeightListeners(e.target);
                reportHeightSoon();
            }, true);

            // Detect taps on non-link elements
            document.addEventListener('click', function(e) {
                if (Date.now() < ignoreClickUntil) {
                    return;
                }
                if (pressStartTimestamp > 0 && Date.now() - pressStartTimestamp > \(InteractionTiming.pressToTapThresholdMs)) {
                    return;
                }
                if (isInsideLink(e.target)) {
                    return; // Don't send tap message if clicking on a link
                }
                // Only send tap message if not clicking on a link
                window.webkit.messageHandlers.tapHandler.postMessage('tap');
                e.preventDefault();
            }, true);
            \(suppressLongPressInteractions ? """
            document.addEventListener('selectstart', function(e) {
                if (isInsideLink(e.target)) {
                    return;
                }
                e.preventDefault();
            }, true);
            """ : "")
            setTimeout(reportHeightSoon, 100);
            setTimeout(reportHeightSoon, 300);
            setTimeout(reportHeightSoon, 700);
            setTimeout(reportHeightSoon, 1500);
            setTimeout(resetScrollPosition, 50);
            setTimeout(resetScrollPosition, 250);
            setTimeout(resetScrollPosition, 750);
            setTimeout(resetScrollPosition, 1500);
            resetScrollPosition();
            reportHeightSoon();
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
            context.coordinator.webView = webView
            context.coordinator.enforceTopViewport(on: webView)

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
                
                body, body *:not(a):not(a *) {
                    -webkit-user-select: none !important;
                    user-select: none !important;
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

        class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler, UIScrollViewDelegate, UIContextMenuInteractionDelegate {
            private enum ContextMenuCommitTarget {
                case post(id: String)
                case link(url: URL)
            }

            var parent: HTMLWebView
            var lastContentKey: HTMLContentKey?
            /// Content key captured at navigation start, used to verify
            /// that the finished navigation still matches the current content.
            var pendingContentKey: HTMLContentKey?
            weak var webView: WKWebView?
            private var ignoreTapUntil: Date = .distantPast
            private var relationshipHandle: String?
            private var relationshipState: ActorRelationshipState?
            private var isLoadingRelationship = false
            private var isApplyingRelationshipAction = false
            private var lastPressedLinkURL: URL?
            private var lastPressedLinkAt: Date = .distantPast
            private var pendingCommitTarget: ContextMenuCommitTarget?

            init(_ parent: HTMLWebView) {
                self.parent = parent
            }

            func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
                // Verify the finished navigation matches the most recently requested content.
                // If a newer load was initiated while this one was in-flight, discard the result
                // to prevent caching a height under the wrong content key.
                guard let pending = pendingContentKey, pending == lastContentKey else { return }

                enforceTopViewport(on: webView)
                measureAndApplyHeight(from: webView, key: pending)
                let delayedMeasurements: [TimeInterval] = [0.15, 0.4, 0.8, 1.5, 2.5, 4.0, 6.0]
                for delay in delayedMeasurements {
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, weak webView] in
                        guard let self, let webView else { return }
                        self.enforceTopViewport(on: webView)
                        self.measureAndApplyHeight(from: webView, key: pending)
                    }
                }
            }

            func enforceTopViewport(on webView: WKWebView) {
                webView.scrollView.setContentOffset(.zero, animated: false)
                webView.evaluateJavaScript(
                    "window.scrollTo(0,0);document.documentElement.scrollTop=0;document.body.scrollTop=0;",
                    completionHandler: nil
                )
            }

            private func measureAndApplyHeight(from webView: WKWebView, key: HTMLContentKey) {
                webView.evaluateJavaScript(
                    """
                    (function() {
                        var body = document.body;
                        var contentRoot = document.getElementById('content-root');
                        var bodyStyle = body ? window.getComputedStyle(body) : null;
                        var bodyPaddingTop = bodyStyle ? parseFloat(bodyStyle.paddingTop || '0') : 0;
                        var bodyPaddingBottom = bodyStyle ? parseFloat(bodyStyle.paddingBottom || '0') : 0;
                        if (contentRoot) {
                            var contentRect = contentRoot.getBoundingClientRect();
                            return Math.ceil(contentRect.height + bodyPaddingTop + bodyPaddingBottom);
                        }
                        var bodyRect = body ? body.getBoundingClientRect() : null;
                        return Math.ceil(Math.max(
                            body ? body.scrollHeight : 0,
                            body ? body.offsetHeight : 0,
                            bodyRect ? bodyRect.height : 0
                        ));
                    })()
                    """
                ) { result, _ in
                    let measuredHeight: CGFloat?
                    if let number = result as? NSNumber {
                        measuredHeight = CGFloat(truncating: number)
                    } else if let doubleValue = result as? Double {
                        measuredHeight = CGFloat(doubleValue)
                    } else if let intValue = result as? Int {
                        measuredHeight = CGFloat(intValue)
                    } else {
                        measuredHeight = nil
                    }

                    guard let measuredHeight, measuredHeight > 0 else { return }

                    DispatchQueue.main.async {
                        // Re-check after the async gap to avoid stale writes.
                        guard let currentKey = self.lastContentKey, currentKey == key else { return }
                        self.enforceTopViewport(on: webView)
                        HTMLHeightCache.shared.setHeight(measuredHeight, for: key)
                        if abs(self.parent.height - measuredHeight) > 0.5 {
                            self.parent.height = measuredHeight
                        }
                    }
                }
            }

            func scrollViewDidScroll(_ scrollView: UIScrollView) {
                let offset = scrollView.contentOffset
                guard abs(offset.x) > 0.5 || abs(offset.y) > 0.5 else { return }
                scrollView.setContentOffset(.zero, animated: false)
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
                            (parent.externalURLRouter ?? .shared).open(url)
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
                if message.name == "linkPressHandler" {
                    guard let rawURL = message.body as? String,
                          !rawURL.isEmpty,
                          let pressedURL = normalizedURL(from: rawURL)
                    else {
                        lastPressedLinkURL = nil
                        lastPressedLinkAt = .distantPast
                        parent.onLinkPressStateChange?(nil)
                        return
                    }

                    lastPressedLinkURL = pressedURL
                    lastPressedLinkAt = Date()
                    parent.onLinkPressStateChange?(pressedURL)
                    return
                }

                if message.name == "heightHandler" {
                    guard let key = lastContentKey else { return }

                    let measuredHeight: CGFloat?
                    if let number = message.body as? NSNumber {
                        measuredHeight = CGFloat(truncating: number)
                    } else if let doubleValue = message.body as? Double {
                        measuredHeight = CGFloat(doubleValue)
                    } else if let intValue = message.body as? Int {
                        measuredHeight = CGFloat(intValue)
                    } else {
                        measuredHeight = nil
                    }

                    guard let measuredHeight, measuredHeight > 0 else { return }

                    DispatchQueue.main.async {
                        guard self.lastContentKey == key else { return }
                        if let webView = self.webView {
                            self.enforceTopViewport(on: webView)
                        }
                        HTMLHeightCache.shared.setHeight(measuredHeight, for: key)
                        if abs(self.parent.height - measuredHeight) > 0.5 {
                            self.parent.height = measuredHeight
                        }
                    }
                    return
                }

                if message.name == "tapHandler" {
                    guard Date() >= ignoreTapUntil else { return }
                    parent.onTap?()
                }
            }

            // MARK: - WKUIDelegate context menu (disabled — handled by UIContextMenuInteraction)

            func webView(
                _: WKWebView,
                contextMenuConfigurationForElement _: WKContextMenuElementInfo,
                completionHandler: @escaping (UIContextMenuConfiguration?) -> Void
            ) {
                // All context menus are now handled by our custom UIContextMenuInteraction
                // which supports both links AND non-link post sneak peek.
                completionHandler(nil)
            }

            // MARK: - UIContextMenuInteractionDelegate

            func contextMenuInteraction(
                _: UIContextMenuInteraction,
                configurationForMenuAtLocation _: CGPoint
            ) -> UIContextMenuConfiguration? {
                if let linkURL = fallbackPressedLinkURL() {
                    pendingCommitTarget = .link(url: linkURL)
                    return makeLinkContextMenuConfiguration(url: linkURL)
                }

                guard let postId = parent.sneakPeekPostId else {
                    pendingCommitTarget = nil
                    return nil
                }

                pendingCommitTarget = .post(id: postId)
                return makePostContextMenuConfiguration()
            }

            func contextMenuInteraction(
                _: UIContextMenuInteraction,
                willPerformPreviewActionForMenuWith _: UIContextMenuConfiguration,
                animator: UIContextMenuInteractionCommitAnimating
            ) {
                guard let target = pendingCommitTarget else { return }
                animator.addCompletion { [weak self] in
                    self?.commitContextMenuTarget(target)
                }
            }

            func contextMenuInteraction(
                _: UIContextMenuInteraction,
                willDisplayMenuFor _: UIContextMenuConfiguration,
                animator _: UIContextMenuInteractionAnimating?
            ) {
                ignoreTapUntil = Date().addingTimeInterval(InteractionTiming.ignoreTapAfterMenuOpen)
            }

            func contextMenuInteraction(
                _: UIContextMenuInteraction,
                willEndFor _: UIContextMenuConfiguration,
                animator _: UIContextMenuInteractionAnimating?
            ) {
                ignoreTapUntil = Date().addingTimeInterval(InteractionTiming.ignoreTapAfterMenuEnd)
                lastPressedLinkURL = nil
                lastPressedLinkAt = .distantPast
                pendingCommitTarget = nil
                parent.onLinkPressStateChange?(nil)
            }

            private func fallbackPressedLinkURL() -> URL? {
                guard Date().timeIntervalSince(lastPressedLinkAt) <= InteractionTiming.linkPressFallbackWindow else {
                    return nil
                }
                return lastPressedLinkURL
            }

            private func normalizedURL(from rawURL: String) -> URL? {
                let trimmed = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }

                if let parsed = URL(string: trimmed), parsed.scheme != nil {
                    return parsed
                }

                let spaceEscaped = trimmed.replacingOccurrences(of: " ", with: "%20")
                if let parsed = URL(string: spaceEscaped), parsed.scheme != nil {
                    return parsed
                }

                if let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed),
                   let parsed = URL(string: encoded),
                   parsed.scheme != nil
                {
                    return parsed
                }

                return nil
            }

            private func commitContextMenuTarget(_ target: ContextMenuCommitTarget) {
                switch target {
                case .post(let id):
                    DispatchQueue.main.async {
                        self.parent.navigationCoordinator?.navigateToPost(id: id)
                    }
                case .link(let url):
                    DispatchQueue.main.async {
                        if url.host == "hackers.pub", url.path.hasPrefix("/@") {
                            let handle = String(url.path.dropFirst(2))
                            self.parent.navigationCoordinator?.navigateToProfile(handle: handle)
                        } else {
                            (self.parent.externalURLRouter ?? .shared).open(url)
                        }
                    }
                }
            }

            private func makePostPreviewController(postId: String) -> UIViewController {
                let basePreview = AnyView(
                    PostDetailView(postId: postId)
                        .frame(width: SneakPeekPreviewLayout.width, height: SneakPeekPreviewLayout.height)
                        .ignoresSafeArea()
                        .environmentObject(FontSettingsManager.shared)
                )
                let finalPreview = injectPreviewEnvironment(into: basePreview)

                let controller = UIHostingController(rootView: finalPreview)
                controller.view.backgroundColor = .systemBackground
                controller.view.insetsLayoutMarginsFromSafeArea = false
                controller.view.directionalLayoutMargins = .zero
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
                if let externalURLRouter = parent.externalURLRouter {
                    result = AnyView(result.environment(externalURLRouter))
                }
                return result
            }

            private func makePostContextMenuConfiguration() -> UIContextMenuConfiguration {
                UIContextMenuConfiguration(
                    identifier: nil,
                    previewProvider: { [weak self] in
                        guard let self, let postId = self.parent.sneakPeekPostId else { return nil }
                        return self.makePostPreviewController(postId: postId)
                    },
                    actionProvider: { [weak self] _ in
                        guard let self else { return UIMenu(children: []) }
                        return self.makeContextMenu()
                    }
                )
            }

            private func makeLinkContextMenuConfiguration(url: URL) -> UIContextMenuConfiguration {
                UIContextMenuConfiguration(
                    identifier: nil,
                    previewProvider: {
                        SFSafariViewController(url: url)
                    },
                    actionProvider: { [weak self] _ in
                        guard let self else { return UIMenu(children: []) }

                        let openAction = UIAction(
                            title: NSLocalizedString("sneakpeek.action.openLink", comment: "Open link"),
                            image: UIImage(systemName: "safari")
                        ) { _ in
                            (self.parent.externalURLRouter ?? .shared).open(url)
                        }

                        let shareAction = UIAction(
                            title: NSLocalizedString("sneakpeek.action.shareLink", comment: "Share link"),
                            image: UIImage(systemName: "square.and.arrow.up")
                        ) { [weak self] _ in
                            self?.presentShareSheet(items: [url])
                        }

                        return UIMenu(children: [openAction, shareAction])
                    }
                )
            }

            private func makeContextMenu() -> UIMenu {
                var children: [UIMenuElement] = []

                if let shareURL = parent.sneakPeekShareURL {
                    let shareAction = UIAction(
                        title: NSLocalizedString("sneakpeek.action.sharePost", comment: "Share post"),
                        image: UIImage(systemName: "square.and.arrow.up")
                    ) { [weak self] _ in
                        self?.presentShareSheet(items: [shareURL])
                    }
                    children.append(shareAction)
                }

                if let userMenu = makeUserActionMenu() {
                    children.append(userMenu)
                }

                return UIMenu(children: children)
            }

            private func makeUserActionMenu() -> UIMenu? {
                guard let handle = parent.sneakPeekActorHandle else { return nil }

                var userChildren: [UIMenuElement] = []

                if parent.authManager?.isAuthenticated == true {
                    userChildren.append(
                        UIDeferredMenuElement { [weak self] completion in
                            guard let self else {
                                completion([])
                                return
                            }
                            Task {
                                _ = await self.loadRelationshipIfNeeded()
                                let elements = await MainActor.run {
                                    self.relationshipActionElements()
                                }
                                completion(elements)
                            }
                        }
                    )
                }

                if let profileURL = actorProfileURL(handle: handle) {
                    let shareProfileAction = UIAction(
                        title: NSLocalizedString("sneakpeek.action.shareProfileLink", comment: "Share profile link"),
                        image: UIImage(systemName: "link")
                    ) { [weak self] _ in
                        self?.presentShareSheet(items: [profileURL])
                    }
                    userChildren.append(shareProfileAction)
                }

                return UIMenu(
                    title: NSLocalizedString("sneakpeek.menu.user", comment: "User menu"),
                    options: .displayInline,
                    children: userChildren
                )
            }

            private func relationshipActionElements() -> [UIMenuElement] {
                guard let relationshipState, !relationshipState.isViewer else {
                    return []
                }

                let followAction = UIAction(
                    title: relationshipState.viewerFollows
                        ? NSLocalizedString("sneakpeek.action.unfollow", comment: "Unfollow action")
                        : NSLocalizedString("sneakpeek.action.follow", comment: "Follow action"),
                    image: UIImage(systemName: relationshipState.viewerFollows ? "person.badge.minus" : "person.badge.plus")
                ) { [weak self] _ in
                    self?.performRelationshipAction(relationshipState.viewerFollows ? .unfollow : .follow)
                }

                let blockAction = UIAction(
                    title: relationshipState.viewerBlocks
                        ? NSLocalizedString("sneakpeek.action.unblock", comment: "Unblock action")
                        : NSLocalizedString("sneakpeek.action.block", comment: "Block action"),
                    image: UIImage(systemName: relationshipState.viewerBlocks ? "nosign" : "hand.raised"),
                    attributes: relationshipState.viewerBlocks ? [] : [.destructive]
                ) { [weak self] _ in
                    self?.performRelationshipAction(relationshipState.viewerBlocks ? .unblock : .block)
                }

                return [followAction, blockAction]
            }

            private func performRelationshipAction(_ action: ActorRelationshipAction) {
                guard !isApplyingRelationshipAction else { return }
                guard let relationshipState else {
                    Task {
                        _ = await loadRelationshipIfNeeded(forceNetwork: true)
                    }
                    return
                }

                isApplyingRelationshipAction = true
                Task {
                    defer { isApplyingRelationshipAction = false }
                    do {
                        try await ActorRelationshipService.perform(action: action, actorId: relationshipState.actorId)
                        if let handle = parent.sneakPeekActorHandle {
                            self.relationshipState = try await ActorRelationshipService.fetch(handle: handle, cachePolicy: .networkOnly)
                            self.relationshipHandle = handle
                        }
                    } catch {
                        presentErrorAlert(message: error.localizedDescription)
                    }
                }
            }

            @discardableResult
            func loadRelationshipIfNeeded(forceNetwork: Bool = false) async -> ActorRelationshipState? {
                guard parent.authManager?.isAuthenticated == true,
                      let handle = parent.sneakPeekActorHandle
                else {
                    relationshipState = nil
                    relationshipHandle = nil
                    return nil
                }

                if isLoadingRelationship {
                    return relationshipState
                }

                if !forceNetwork, relationshipHandle == handle, let relationshipState {
                    return relationshipState
                }

                isLoadingRelationship = true
                defer { isLoadingRelationship = false }
                do {
                    let fetchedRelationship = try await ActorRelationshipService.fetch(
                        handle: handle,
                        cachePolicy: forceNetwork ? .networkOnly : .networkFirst
                    )
                    relationshipState = fetchedRelationship
                    relationshipHandle = handle
                    return fetchedRelationship
                } catch {
                    relationshipState = nil
                    return nil
                }
            }

            private func presentShareSheet(items: [Any]) {
                ShareSheetPresenter.present(items: items, from: webView)
            }

            private func presentErrorAlert(message: String) {
                guard let presenter = topViewController() else { return }

                let alert = UIAlertController(
                    title: NSLocalizedString("actorRelation.error.title", comment: "Actor relation action error title"),
                    message: message,
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: NSLocalizedString("compose.error.ok", comment: "OK button"), style: .default))
                presenter.present(alert, animated: true)
            }

            private func topViewController(startingAt root: UIViewController? = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first(where: \.isKeyWindow)?
                .rootViewController) -> UIViewController?
            {
                guard let root else { return nil }

                if let presented = root.presentedViewController {
                    return topViewController(startingAt: presented)
                }

                if let navigationController = root as? UINavigationController {
                    return topViewController(startingAt: navigationController.visibleViewController)
                }

                if let tabBarController = root as? UITabBarController {
                    return topViewController(startingAt: tabBarController.selectedViewController)
                }

                return root
            }

        }
    }
#endif
