import SwiftUI
import WebKit

struct FontSettingsSnapshot: Equatable {
    let fontName: String
    let sizeMultiplier: Double
    let useSystemDynamicType: Bool

    init(from manager: FontSettingsManager) {
        fontName = manager.selectedFontName
        sizeMultiplier = manager.fontSizeMultiplier
        useSystemDynamicType = manager.useSystemDynamicType
    }
}

#if os(macOS)
    struct MarkdownPreviewView: NSViewRepresentable {
        let html: String
        @Binding var isLoading: Bool
        @ObservedObject private var fontSettings = FontSettingsManager.shared

        func makeNSView(context: Context) -> WKWebView {
            let webView = WKWebView()
            webView.setValue(false, forKey: "drawsBackground")
            webView.navigationDelegate = context.coordinator
            return webView
        }

        func updateNSView(_ webView: WKWebView, context: Context) {
            // Update the coordinator's binding reference
            context.coordinator.isLoading = $isLoading

            // Check if HTML or font settings have changed
            let currentFontSettings = FontSettingsSnapshot(from: fontSettings)
            let contentChanged = context.coordinator.lastHTML != html
            let fontChanged = context.coordinator.lastFontSettings != currentFontSettings

            if contentChanged || fontChanged {
                context.coordinator.lastHTML = html
                context.coordinator.lastFontSettings = currentFontSettings
                webView.loadHTMLString(html, baseURL: nil)
            }
        }

        func makeCoordinator() -> Coordinator {
            Coordinator(isLoading: $isLoading)
        }

        static func dismantleNSView(_ nsView: WKWebView, coordinator _: Coordinator) {
            HTMLWebViewLifecycle.dismantle(nsView)
        }

        class Coordinator: NSObject, WKNavigationDelegate {
            var isLoading: Binding<Bool>
            var lastHTML: String = ""
            var lastFontSettings: FontSettingsSnapshot?

            init(isLoading: Binding<Bool>) {
                self.isLoading = isLoading
            }

            func webView(_: WKWebView, didStartProvisionalNavigation _: WKNavigation!) {
                isLoading.wrappedValue = true
            }

            func webView(_: WKWebView, didFinish _: WKNavigation!) {
                isLoading.wrappedValue = false
            }

            func webView(_: WKWebView, didFail _: WKNavigation!, withError _: Error) {
                isLoading.wrappedValue = false
            }

            // swiftlint:disable:next line_length
            func webView(_: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
                if navigationAction.navigationType == .linkActivated {
                    if let url = navigationAction.request.url {
                        if ExternalURLOpeningPolicy.action(
                            for: url,
                            useInAppBrowser: false
                        ) != .consumeOwnedScheme {
                            NSWorkspace.shared.open(url)
                        }
                        decisionHandler(.cancel)
                        return
                    }
                }
                decisionHandler(.allow)
            }
        }
    }
#else
    struct MarkdownPreviewView: UIViewRepresentable {
        let html: String
        @Binding var isLoading: Bool
        @ObservedObject private var fontSettings = FontSettingsManager.shared
        @Environment(\.dynamicTypeSize) private var dynamicTypeSize
        @Environment(ExternalURLRouter.self) private var externalURLRouter
        @Environment(AuthManager.self) private var authManager
        @Environment(NavigationCoordinator.self) private var navigationCoordinator

        func makeUIView(context: Context) -> WKWebView {
            let webView = WKWebView(frame: .zero, configuration: HTMLWebSecurityConfiguration.make())
            webView.isOpaque = false
            webView.backgroundColor = .clear
            webView.navigationDelegate = context.coordinator
            webView.uiDelegate = context.coordinator
            return webView
        }

        func updateUIView(_ webView: WKWebView, context: Context) {
            // Update the coordinator's binding reference
            context.coordinator.isLoading = $isLoading
            context.coordinator.externalURLRouter = externalURLRouter
            context.coordinator.authManager = authManager
            context.coordinator.navigationCoordinator = navigationCoordinator

            // Check if HTML or font settings have changed
            let currentFontSettings = FontSettingsSnapshot(from: fontSettings)
            let contentChanged = context.coordinator.lastHTML != html
            let fontChanged = context.coordinator.lastFontSettings != currentFontSettings
            let dynamicTypeChanged = context.coordinator.lastDynamicTypeSize != dynamicTypeSize

            if contentChanged || fontChanged || dynamicTypeChanged {
                context.coordinator.lastHTML = html
                context.coordinator.lastFontSettings = currentFontSettings
                context.coordinator.lastDynamicTypeSize = dynamicTypeSize
                context.coordinator.beginInitialDocumentLoad()
                webView.loadHTMLString(html, baseURL: nil)
            }
        }

        func makeCoordinator() -> Coordinator {
            Coordinator(isLoading: $isLoading)
        }

        static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
            HTMLWebViewLifecycle.dismantle(uiView)
            coordinator.detach()
        }

        class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
            var isLoading: Binding<Bool>
            var lastHTML: String = ""
            var lastFontSettings: FontSettingsSnapshot?
            var lastDynamicTypeSize: DynamicTypeSize?
            var externalURLRouter: ExternalURLRouter?
            private var pendingInitialDocumentLoads = 0
            var authManager: AuthManager?
            var navigationCoordinator: NavigationCoordinator?

            init(isLoading: Binding<Bool>) {
                self.isLoading = isLoading
            }

            func beginInitialDocumentLoad() {
                pendingInitialDocumentLoads += 1
            }

            func navigationDecision(
                for request: HTMLWebNavigationRequest
            ) -> HTMLWebNavigationPolicy.Decision {
                let decision = HTMLWebNavigationPolicy.decision(
                    for: request,
                    allowsInitialDocumentLoad: pendingInitialDocumentLoads > 0
                )
                if decision == .allowInitialDocument, pendingInitialDocumentLoads > 0 {
                    pendingInitialDocumentLoads -= 1
                }
                return decision
            }

            func detach() {
                pendingInitialDocumentLoads = 0
            }

            func webView(_: WKWebView, didStartProvisionalNavigation _: WKNavigation!) {
                isLoading.wrappedValue = true
            }

            func webView(_: WKWebView, didFinish _: WKNavigation!) {
                isLoading.wrappedValue = false
            }

            func webView(_: WKWebView, didFail _: WKNavigation!, withError _: Error) {
                isLoading.wrappedValue = false
            }

            // swiftlint:disable:next line_length cyclomatic_complexity
            func webView(_: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
                if navigationAction.navigationType == .linkActivated {
                    if let url = navigationAction.request.url {
                        switch RendererLinkRoutingPolicy.action(
                            for: url,
                            hasNavigationCoordinator: navigationCoordinator != nil
                        ) {
                        case .consumeOwnedScheme:
                            break
                        case .inAppBrowser:
                            (externalURLRouter ?? .shared).openInApp(url)
                        case .external:
                            (externalURLRouter ?? .shared).open(url)
                        case .deepLink:
                            if let navigationCoordinator {
                                DeepLinkNavigator.open(
                                    url,
                                    authManager: authManager ?? .shared,
                                    navigationCoordinator: navigationCoordinator,
                                    externalURLRouter: externalURLRouter ?? .shared
                                )
                            }
                        }
                        decisionHandler(.cancel)
                        return
                    }
                }

                let kind: HTMLWebNavigationKind
                switch navigationAction.navigationType {
                case .linkActivated:
                    kind = .linkActivated
                case .formSubmitted:
                    kind = .formSubmitted
                default:
                    kind = .other
                }
                let request = HTMLWebNavigationRequest(
                    url: navigationAction.request.url,
                    kind: kind,
                    isMainFrame: navigationAction.targetFrame?.isMainFrame ?? false
                )

                switch navigationDecision(for: request) {
                case .allowInitialDocument:
                    decisionHandler(.allow)
                case let .route(url):
                    (externalURLRouter ?? .shared).open(url)
                    decisionHandler(.cancel)
                case .cancel:
                    decisionHandler(.cancel)
                }
            }

            func webView(
                _: WKWebView,
                createWebViewWith _: WKWebViewConfiguration,
                for _: WKNavigationAction,
                windowFeatures _: WKWindowFeatures
            ) -> WKWebView? {
                nil
            }
        }
    }
#endif
