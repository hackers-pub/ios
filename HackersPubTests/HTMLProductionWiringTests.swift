// swiftlint:disable file_length
import CoreGraphics
import Foundation
@testable import HackersPub
import SwiftUI
import Testing
import UIKit
import WebKit

@MainActor
// swiftlint:disable:next type_body_length
struct HTMLProductionWiringTests {
    @Test
    // swiftlint:disable:next function_body_length
    func contentPlanDrivesRendererSelectionMediaRetryLayoutAndIdentity() throws {
        let staticFeed = HTMLContentRenderPlan.make(.init(
            html: "<p>plain preview</p>",
            media: [],
            renderMode: .lightweightText,
            renderingContext: .feedPreview,
            hasTapHandler: false,
            sneakPeekPostId: nil,
            sneakPeekShareURL: nil,
            mediaContainerWidth: 0,
            displayScale: 2
        ))
        #expect(staticFeed.rendererKind == .staticText)
        #expect(!staticFeed.allowsTextSelection)

        let interactiveFeed = HTMLContentRenderPlan.make(.init(
            html: "<a href=\"https://example.com\">linked preview</a>",
            media: [],
            renderMode: .lightweightText,
            renderingContext: .feedPreview,
            hasTapHandler: false,
            sneakPeekPostId: "post-17",
            sneakPeekShareURL: nil,
            mediaContainerWidth: 0,
            displayScale: 2
        ))
        #expect(interactiveFeed.rendererKind == .interactiveText)
        #expect(!interactiveFeed.allowsTextSelection)
        #expect(interactiveFeed.contentIdentity == "post-17")

        let profile = HTMLContentRenderPlan.make(.init(
            html: "<p>select me</p>",
            media: [],
            renderMode: .lightweightText,
            renderingContext: .profileBio,
            hasTapHandler: false,
            sneakPeekPostId: nil,
            sneakPeekShareURL: nil,
            mediaContainerWidth: 0,
            displayScale: 2
        ))
        #expect(profile.rendererKind == .interactiveText)
        #expect(profile.allowsTextSelection)

        let media = MediaItem(
            id: "media-17",
            url: "https://example.com/original.jpg",
            thumbnailUrl: "https://example.com/thumbnail.jpg",
            alt: "production media",
            width: 800,
            height: 400
        )
        let detail = HTMLContentRenderPlan.make(.init(
            html: "<p>rich detail</p>",
            media: [media],
            renderMode: .richWebView,
            renderingContext: .detail,
            hasTapHandler: false,
            sneakPeekPostId: nil,
            sneakPeekShareURL: nil,
            mediaContainerWidth: 320,
            displayScale: 2
        ))

        #expect(detail.rendererKind == .richWebView)
        #expect(detail.contentIdentity == "<p>rich detail</p>")
        #expect(detail.carouselHeight == 160)
        let mediaPlan = try #require(detail.media.first)
        #expect(mediaPlan.item.id == "media-17")
        #expect(mediaPlan.sourceURL == URL(string: "https://example.com/thumbnail.jpg"))
        #expect(mediaPlan.downsamplingSize == CGSize(width: 640, height: 320))
        #expect(mediaPlan.cancelsOnDisappear)
    }

    @Test
    // swiftlint:disable:next function_body_length
    func mountedHTMLWebViewUsesProductionSecuritySanitizationScriptAndTeardown() async throws {
        var measuredHeight: CGFloat = 0
        let source = """
        <p id="safe" onclick="window.bad = true">safe</p>
        <script>window.bad = true</script>
        <a id="unsafe-link" href="javascript:window.bad = true">unsafe</a>
        """
        let host = RendererViewHost(
            HTMLWebView(
                html: source,
                height: Binding(
                    get: { measuredHeight },
                    set: { measuredHeight = $0 }
                )
            )
        )
        defer { host.close() }

        let webView = try await host.firstSubview(ofType: WKWebView.self)
        #expect(!webView.configuration.defaultWebpagePreferences.allowsContentJavaScript)
        #expect(!webView.configuration.preferences.javaScriptCanOpenWindowsAutomatically)
        #expect(webView.navigationDelegate is HTMLWebView.Coordinator)
        #expect(webView.uiDelegate is HTMLWebView.Coordinator)
        #expect(webView.scrollView.delegate is HTMLWebView.Coordinator)

        let userScripts = webView.configuration.userContentController.userScripts
        #expect(userScripts.count == 1)
        let installedSource = try #require(userScripts.first?.source)
        let generationRange = try #require(
            installedSource.range(
                of: #"generation:\s*[1-9][0-9]*"#,
                options: .regularExpression
            )
        )
        let generationText = String(installedSource[generationRange])
        let generation = try #require(
            UInt64(
                generationText
                    .replacingOccurrences(of: "generation:", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            )
        )
        #expect(installedSource.contains("height: computedDocumentHeight()"))

        let coordinator = try #require(webView.navigationDelegate as? HTMLWebView.Coordinator)
        #expect(coordinator.processHeightMessageBody(["generation": generation, "height": 123]))
        #expect(measuredHeight == 123)
        #expect(!coordinator.processHeightMessageBody(["generation": generation + 1, "height": 456]))
        #expect(measuredHeight == 123)

        try await eventually(attempts: 500) {
            let text = try? await webView.evaluateJavaScript(
                "document.querySelector('p')?.textContent"
            ) as? String
            return text == "safe"
        }

        let scriptResult = try await webView.evaluateJavaScript(
            "document.querySelector('script') !== null"
        )
        let hasScript = try #require(scriptResult as? Bool)
        let inlineHandlerResult = try await webView.evaluateJavaScript(
            "document.querySelector('[onclick]') !== null"
        )
        let hasInlineHandler = try #require(inlineHandlerResult as? Bool)
        let unsafeLinkTarget = try await webView.evaluateJavaScript(
            "document.querySelector('a').getAttribute('href')"
        )
        #expect(!hasScript)
        #expect(!hasInlineHandler)
        #expect(unsafeLinkTarget == nil || unsafeLinkTarget is NSNull)

        host.update(EmptyView())
        try await eventually {
            webView.navigationDelegate == nil &&
                webView.uiDelegate == nil &&
                webView.scrollView.delegate == nil &&
                webView.configuration.userContentController.userScripts.isEmpty
        }
    }

    @Test
    func mountedMarkdownUsesSharedSecurityAndCancelsLinksAndPopups() async throws {
        var isLoading = false
        let router = ExternalURLRouter()
        router.useInAppBrowser = true
        let navigationCoordinator = NavigationCoordinator()
        let markdown = MarkdownPreviewView(
            html: "<a id=\"external\" href=\"https://example.com/markdown\">external</a>",
            isLoading: Binding(
                get: { isLoading },
                set: { isLoading = $0 }
            )
        )
        let host = RendererViewHost(
            appEnvironment(
                markdown,
                navigationCoordinator: navigationCoordinator,
                externalURLRouter: router
            )
        )
        defer { host.close() }

        let webView = try await host.firstSubview(ofType: WKWebView.self)
        #expect(!webView.configuration.defaultWebpagePreferences.allowsContentJavaScript)
        #expect(!webView.configuration.preferences.javaScriptCanOpenWindowsAutomatically)
        #expect(webView.navigationDelegate is MarkdownPreviewView.Coordinator)
        #expect(webView.uiDelegate is MarkdownPreviewView.Coordinator)

        try await eventually {
            let href = try? await webView.evaluateJavaScript(
                "document.querySelector('a')?.getAttribute('href')"
            ) as? String
            return href == "https://example.com/markdown"
        }

        _ = try await webView.evaluateJavaScript("document.querySelector('a').click()")
        try await eventually {
            router.destination?.url == URL(string: "https://example.com/markdown")
        }
        #expect(webView.url?.host != "example.com")

        let popupResult = try await webView.evaluateJavaScript(
            "window.open('https://example.com/popup', '_blank') === null"
        )
        let popupWasRejected = try #require(popupResult as? Bool)
        #expect(popupWasRejected)
        #expect(host.subviews(ofType: WKWebView.self).count == 1)
    }

    @Test
    // swiftlint:disable:next function_body_length
    func mountedContentUsesPlannedRendererKindsAndReplacesRichIdentity() async throws {
        let router = ExternalURLRouter()
        let navigationCoordinator = NavigationCoordinator()

        let interactiveHost = RendererViewHost(
            appEnvironment(
                HTMLContentView(
                    html: "<p>interactive feed</p>",
                    media: [],
                    renderMode: .lightweightText,
                    renderingContext: .feedPreview,
                    onTap: {}
                ),
                navigationCoordinator: navigationCoordinator,
                externalURLRouter: router
            )
        )
        _ = try await interactiveHost.firstSubview(ofType: SelfSizingHTMLLabel.self)
        #expect(interactiveHost.subviews(ofType: SelfSizingSelectableHTMLTextView.self).isEmpty)
        #expect(interactiveHost.subviews(ofType: WKWebView.self).isEmpty)
        interactiveHost.close()

        let profileHost = RendererViewHost(
            appEnvironment(
                HTMLContentView(
                    html: "<p>selectable profile</p>",
                    media: [],
                    renderMode: .lightweightText,
                    renderingContext: .profileBio
                ),
                navigationCoordinator: navigationCoordinator,
                externalURLRouter: router
            )
        )
        let selectable = try await profileHost.firstSubview(ofType: SelfSizingSelectableHTMLTextView.self)
        #expect(selectable.isSelectable)
        #expect(!selectable.isEditable)
        profileHost.close()

        let richHost = RendererViewHost(
            appEnvironment(
                HTMLContentView(
                    html: "<p>old rich identity</p>",
                    media: [],
                    renderingContext: .detail
                ),
                navigationCoordinator: navigationCoordinator,
                externalURLRouter: router
            )
        )
        defer { richHost.close() }
        let oldWebView = try await richHost.firstSubview(ofType: WKWebView.self)

        richHost.update(
            appEnvironment(
                HTMLContentView(
                    html: "<p>new rich identity</p>",
                    media: [],
                    renderingContext: .detail
                ),
                navigationCoordinator: navigationCoordinator,
                externalURLRouter: router
            )
        )
        let newWebView = try await richHost.firstSubview(
            ofType: WKWebView.self,
            where: { $0 !== oldWebView }
        )
        #expect(newWebView !== oldWebView)
        try await eventually {
            oldWebView.navigationDelegate == nil &&
                oldWebView.configuration.userContentController.userScripts.isEmpty
        }
    }

    @Test
    // swiftlint:disable:next function_body_length
    func productionTextCoordinatorsRejectHeightsFromReplacedRenderGenerations() async {
        var selectableHeight: CGFloat = 0
        let selectable = SelectableHTMLTextView(
            html: "old",
            height: Binding(
                get: { selectableHeight },
                set: { selectableHeight = $0 }
            )
        )
        let selectableCoordinator = selectable.makeCoordinator()
        selectableCoordinator.render(
            cacheKey: "selectable-old",
            html: "old",
            uiFont: .systemFont(ofSize: 17),
            uiColor: .label
        )
        selectableCoordinator.updateMeasuredHeight(111)
        selectableCoordinator.render(
            cacheKey: "selectable-new",
            html: "new",
            uiFont: .systemFont(ofSize: 17),
            uiColor: .label
        )
        await drainMainQueue()
        #expect(selectableHeight == 0)

        selectableCoordinator.updateMeasuredHeight(222)
        await drainMainQueue()
        #expect(selectableHeight == 222)

        var interactiveHeight: CGFloat = 0
        let interactive = InteractiveHTMLTextView(
            html: "old",
            height: Binding(
                get: { interactiveHeight },
                set: { interactiveHeight = $0 }
            )
        )
        let interactiveCoordinator = interactive.makeCoordinator()
        interactiveCoordinator.render(
            cacheKey: "interactive-old",
            html: "old",
            uiFont: .systemFont(ofSize: 17),
            uiColor: .label
        )
        interactiveCoordinator.updateMeasuredHeight(333)
        interactiveCoordinator.render(
            cacheKey: "interactive-new",
            html: "new",
            uiFont: .systemFont(ofSize: 17),
            uiColor: .label
        )
        await drainMainQueue()
        #expect(interactiveHeight == 0)

        interactiveCoordinator.updateMeasuredHeight(444)
        await drainMainQueue()
        #expect(interactiveHeight == 444)
    }

    @Test
    func htmlWebCoordinatorAllowsEachScheduledInitialDocumentLoad() throws {
        var height: CGFloat = 0
        let htmlWebView = HTMLWebView(
            html: "<p>coordinator</p>",
            height: Binding(
                get: { height },
                set: { height = $0 }
            )
        )
        let coordinator = htmlWebView.makeCoordinator()
        let initialDocument = try HTMLWebNavigationRequest(
            url: #require(URL(string: "about:blank")),
            kind: .other,
            isMainFrame: true
        )

        coordinator.beginInitialDocumentLoad()
        coordinator.beginInitialDocumentLoad()

        #expect(coordinator.navigationDecision(for: initialDocument) == .allowInitialDocument)
        #expect(coordinator.navigationDecision(for: initialDocument) == .allowInitialDocument)
        #expect(coordinator.navigationDecision(for: initialDocument) == .cancel)
    }
}

@MainActor
private final class RendererViewHost {
    private let hostController: UIHostingController<AnyView>
    private let window: UIWindow

    init<Content: View>(_ content: Content) {
        hostController = UIHostingController(rootView: AnyView(content))
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first
        else {
            fatalError("A window scene is required to mount renderer views")
        }
        window = UIWindow(windowScene: windowScene)
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        window.rootViewController = hostController
        window.makeKeyAndVisible()
        layout()
    }

    func update<Content: View>(_ content: Content) {
        hostController.rootView = AnyView(content)
        layout()
    }

    func subviews<ViewType: UIView>(ofType _: ViewType.Type) -> [ViewType] {
        allSubviews(in: hostController.view).compactMap { $0 as? ViewType }
    }

    func firstSubview<ViewType: UIView>(
        ofType type: ViewType.Type,
        where predicate: @escaping (ViewType) -> Bool = { _ in true }
    ) async throws -> ViewType {
        var match: ViewType?
        try await eventually { [weak self] in
            guard let self else { return false }
            self.layout()
            match = self.subviews(ofType: type).first(where: predicate)
            return match != nil
        }
        return try #require(match)
    }

    func close() {
        hostController.rootView = AnyView(EmptyView())
        layout()
        window.isHidden = true
        window.rootViewController = nil
    }

    private func layout() {
        hostController.view.frame = window.bounds
        hostController.view.setNeedsLayout()
        hostController.view.layoutIfNeeded()
    }

    private func allSubviews(in view: UIView) -> [UIView] {
        [view] + view.subviews.flatMap(allSubviews(in:))
    }
}

@MainActor
private func appEnvironment<Content: View>(
    _ content: Content,
    navigationCoordinator: NavigationCoordinator,
    externalURLRouter: ExternalURLRouter
) -> some View {
    content
        .environment(AuthManager.shared)
        .environment(navigationCoordinator)
        .environment(externalURLRouter)
        .environmentObject(FontSettingsManager.shared)
}

@MainActor
private func eventually(
    attempts: Int = 200,
    _ predicate: @escaping @MainActor () async -> Bool
) async throws {
    for _ in 0 ..< attempts {
        if await predicate() {
            return
        }
        try await Task.sleep(for: .milliseconds(10))
    }
    throw RendererLifecycleTimeout()
}

private struct RendererLifecycleTimeout: Error {}

@MainActor
private func drainMainQueue() async {
    await withCheckedContinuation { continuation in
        DispatchQueue.main.async {
            continuation.resume()
        }
    }
}
