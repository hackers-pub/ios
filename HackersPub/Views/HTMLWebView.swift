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
            static let linkPressFallbackWindow: TimeInterval = 1.5
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
        @Environment(\.dynamicTypeSize) private var dynamicTypeSize
        @ObservedObject private var fontSettings = FontSettingsManager.shared

        // MARK: - UIViewRepresentable

        func makeUIView(context: Context) -> WKWebView {
            let configuration = WKWebViewConfiguration()
            configuration.userContentController.add(context.coordinator, name: "tapHandler")
            configuration.userContentController.add(context.coordinator, name: "linkPressHandler")

            let webView = WKWebView(frame: .zero, configuration: configuration)
            webView.isOpaque = false
            webView.backgroundColor = .clear
            webView.navigationDelegate = context.coordinator
            webView.uiDelegate = context.coordinator
            webView.scrollView.isScrollEnabled = false
            context.coordinator.webView = webView

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
                    window.webkit.messageHandlers.linkPressHandler.postMessage(anchor.href);
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
            document.addEventListener('contextmenu', function(e) {
                if (isInsideLink(e.target)) {
                    return;
                }
                ignoreClickUntil = Date.now() + \(InteractionTiming.suppressClickAfterContextMenuMs);
                e.preventDefault();
            }, true);
            document.addEventListener('selectstart', function(e) {
                if (isInsideLink(e.target)) {
                    return;
                }
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
            context.coordinator.webView = webView
            context.coordinator.refreshRelationshipIfNeeded()

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

        class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
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

            init(_ parent: HTMLWebView) {
                self.parent = parent
            }

            func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
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
                          let pressedURL = URL(string: rawURL)
                    else {
                        lastPressedLinkURL = nil
                        lastPressedLinkAt = .distantPast
                        return
                    }

                    lastPressedLinkURL = pressedURL
                    lastPressedLinkAt = Date()
                    return
                }

                if message.name == "tapHandler" {
                    guard Date() >= ignoreTapUntil else { return }
                    parent.onTap?()
                }
            }

            func webView(
                _: WKWebView,
                contextMenuConfigurationForElement elementInfo: WKContextMenuElementInfo,
                completionHandler: @escaping (UIContextMenuConfiguration?) -> Void
            ) {
                if let linkURL = elementInfo.linkURL ?? fallbackPressedLinkURL() {
                    completionHandler(makeLinkContextMenuConfiguration(url: linkURL))
                    return
                }

                guard parent.sneakPeekPostId != nil else {
                    completionHandler(nil)
                    return
                }

                completionHandler(makePostContextMenuConfiguration())
            }

            func webView(
                _: WKWebView,
                contextMenuWillPresentForElement _: WKContextMenuElementInfo
            ) {
                ignoreTapUntil = Date().addingTimeInterval(InteractionTiming.ignoreTapAfterMenuOpen)
            }

            func webView(
                _: WKWebView,
                contextMenuDidEndForElement _: WKContextMenuElementInfo
            ) {
                ignoreTapUntil = Date().addingTimeInterval(InteractionTiming.ignoreTapAfterMenuEnd)
                lastPressedLinkURL = nil
                lastPressedLinkAt = .distantPast
            }

            private func fallbackPressedLinkURL() -> URL? {
                guard Date().timeIntervalSince(lastPressedLinkAt) <= InteractionTiming.linkPressFallbackWindow else {
                    return nil
                }
                return lastPressedLinkURL
            }

            private func makePostPreviewController(postId: String) -> UIViewController {
                let basePreview = AnyView(
                    PostDetailView(postId: postId)
                        .frame(width: 340, height: 560)
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
                    if let relationshipState, !relationshipState.isViewer {
                        let followAction = UIAction(
                            title: relationshipState.viewerFollows
                                ? NSLocalizedString("sneakpeek.action.unfollow", comment: "Unfollow action")
                                : NSLocalizedString("sneakpeek.action.follow", comment: "Follow action"),
                            image: UIImage(systemName: relationshipState.viewerFollows ? "person.badge.minus" : "person.badge.plus")
                        ) { [weak self] _ in
                            self?.performRelationshipAction(relationshipState.viewerFollows ? .unfollow : .follow)
                        }
                        userChildren.append(followAction)

                        let blockAction = UIAction(
                            title: relationshipState.viewerBlocks
                                ? NSLocalizedString("sneakpeek.action.unblock", comment: "Unblock action")
                                : NSLocalizedString("sneakpeek.action.block", comment: "Block action"),
                            image: UIImage(systemName: relationshipState.viewerBlocks ? "nosign" : "hand.raised"),
                            attributes: relationshipState.viewerBlocks ? [] : [.destructive]
                        ) { [weak self] _ in
                            self?.performRelationshipAction(relationshipState.viewerBlocks ? .unblock : .block)
                        }
                        userChildren.append(blockAction)
                    }
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

            private func performRelationshipAction(_ action: ActorRelationshipAction) {
                guard !isApplyingRelationshipAction else { return }
                guard let relationshipState else {
                    refreshRelationshipIfNeeded(forceNetwork: true)
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

            func refreshRelationshipIfNeeded(forceNetwork: Bool = false) {
                guard parent.authManager?.isAuthenticated == true,
                      let handle = parent.sneakPeekActorHandle
                else {
                    relationshipState = nil
                    relationshipHandle = nil
                    return
                }

                if isLoadingRelationship {
                    return
                }

                if !forceNetwork, relationshipHandle == handle, relationshipState != nil {
                    return
                }

                isLoadingRelationship = true
                Task {
                    defer { isLoadingRelationship = false }
                    do {
                        relationshipState = try await ActorRelationshipService.fetch(
                            handle: handle,
                            cachePolicy: forceNetwork ? .networkOnly : .networkFirst
                        )
                        relationshipHandle = handle
                    } catch {
                        relationshipState = nil
                    }
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
