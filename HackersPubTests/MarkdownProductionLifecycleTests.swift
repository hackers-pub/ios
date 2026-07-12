import CoreGraphics
@testable import HackersPub
import SwiftUI
import Testing
import UIKit
import WebKit

@MainActor
struct MarkdownProductionLifecycleTests {
    @Test
    func rapidUpdatesLoadLatestDocumentAndDismantleClearsPendingPermits() async throws {
        var isLoading = false
        let router = ExternalURLRouter()
        let navigationCoordinator = NavigationCoordinator()
        let loading = Binding(
            get: { isLoading },
            set: { isLoading = $0 }
        )
        let host = MarkdownViewHost(
            markdownEnvironment(
                MarkdownPreviewView(
                    html: "<p id=\"first\">first document</p>",
                    isLoading: loading
                ),
                router: router,
                navigationCoordinator: navigationCoordinator
            )
        )
        defer { host.close() }

        host.update(
            markdownEnvironment(
                MarkdownPreviewView(
                    html: "<p id=\"second\">second document</p>",
                    isLoading: loading
                ),
                router: router,
                navigationCoordinator: navigationCoordinator
            )
        )

        let webView = try await host.firstWebView()
        let coordinator = try #require(webView.navigationDelegate as? MarkdownPreviewView.Coordinator)
        try await waitForMarkdownLifecycle(attempts: 500) {
            let text = try? await webView.evaluateJavaScript(
                "document.querySelector('#second')?.textContent"
            ) as? String
            return text == "second document"
        }

        coordinator.beginInitialDocumentLoad()
        host.update(EmptyView())
        try await waitForMarkdownLifecycle {
            webView.navigationDelegate == nil &&
                webView.uiDelegate == nil &&
                webView.scrollView.delegate == nil
        }
        #expect(coordinator.navigationDecision(for: initialDocumentRequest) == .cancel)
    }

    @Test
    func coordinatorAllowsOneDecisionPerScheduledLoadAndBlocksUnsolicitedNavigation() {
        var isLoading = false
        let preview = MarkdownPreviewView(
            html: "<p>coordinator</p>",
            isLoading: Binding(
                get: { isLoading },
                set: { isLoading = $0 }
            )
        )
        let coordinator = preview.makeCoordinator()

        coordinator.beginInitialDocumentLoad()
        coordinator.beginInitialDocumentLoad()

        #expect(coordinator.navigationDecision(for: initialDocumentRequest) == .allowInitialDocument)
        #expect(coordinator.navigationDecision(for: initialDocumentRequest) == .allowInitialDocument)
        #expect(coordinator.navigationDecision(for: initialDocumentRequest) == .cancel)
        #expect(coordinator.navigationDecision(for: unsolicitedDocumentRequest) == .cancel)

        coordinator.beginInitialDocumentLoad()
        #expect(coordinator.navigationDecision(for: subframeInitialDocumentRequest) == .cancel)
        #expect(coordinator.navigationDecision(for: initialDocumentRequest) == .allowInitialDocument)

        let webView = WKWebView(
            frame: .zero,
            configuration: HTMLWebSecurityConfiguration.make()
        )
        let scrollDelegate = MarkdownScrollDelegate()
        webView.navigationDelegate = coordinator
        webView.uiDelegate = coordinator
        webView.scrollView.delegate = scrollDelegate
        coordinator.beginInitialDocumentLoad()
        MarkdownPreviewView.dismantleUIView(webView, coordinator: coordinator)

        #expect(webView.navigationDelegate == nil)
        #expect(webView.uiDelegate == nil)
        #expect(webView.scrollView.delegate == nil)
        #expect(coordinator.navigationDecision(for: initialDocumentRequest) == .cancel)
    }

    private var initialDocumentRequest: HTMLWebNavigationRequest {
        HTMLWebNavigationRequest(
            url: URL(string: "about:blank")!,
            kind: .other,
            isMainFrame: true
        )
    }

    private var unsolicitedDocumentRequest: HTMLWebNavigationRequest {
        HTMLWebNavigationRequest(
            url: URL(string: "https://example.com/unsolicited")!,
            kind: .other,
            isMainFrame: true
        )
    }

    private var subframeInitialDocumentRequest: HTMLWebNavigationRequest {
        HTMLWebNavigationRequest(
            url: URL(string: "about:blank")!,
            kind: .other,
            isMainFrame: false
        )
    }
}

@MainActor
private final class MarkdownViewHost {
    private let hostController: UIHostingController<AnyView>
    private let window: UIWindow

    init<Content: View>(_ content: Content) {
        hostController = UIHostingController(rootView: AnyView(content))
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first
        else {
            fatalError("A window scene is required to mount MarkdownPreviewView")
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

    func firstWebView() async throws -> WKWebView {
        var match: WKWebView?
        try await waitForMarkdownLifecycle { [weak self] in
            guard let self else { return false }
            self.layout()
            match = self.allSubviews(in: self.hostController.view)
                .compactMap { $0 as? WKWebView }
                .first
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
private func markdownEnvironment<Content: View>(
    _ content: Content,
    router: ExternalURLRouter,
    navigationCoordinator: NavigationCoordinator
) -> some View {
    content
        .environment(AuthManager.shared)
        .environment(navigationCoordinator)
        .environment(router)
}

@MainActor
private func waitForMarkdownLifecycle(
    attempts: Int = 200,
    _ predicate: @escaping @MainActor () async -> Bool
) async throws {
    for _ in 0 ..< attempts {
        if await predicate() {
            return
        }
        try await Task.sleep(for: .milliseconds(10))
    }
    throw MarkdownLifecycleTimeout()
}

private struct MarkdownLifecycleTimeout: Error {}

private final class MarkdownScrollDelegate: NSObject, UIScrollViewDelegate {}
