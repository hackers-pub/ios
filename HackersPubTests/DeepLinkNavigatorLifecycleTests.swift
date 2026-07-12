import Foundation
@testable import HackersPub
import Testing

private actor SuspendedPostResolution {
    private var didStart = false
    private var startContinuation: CheckedContinuation<Void, Never>?
    private var resolutionContinuation: CheckedContinuation<String?, Never>?

    func resolvePostID(for _: String) async -> String? {
        didStart = true
        startContinuation?.resume()
        startContinuation = nil

        return await withCheckedContinuation { continuation in
            resolutionContinuation = continuation
        }
    }

    func waitUntilStarted() async {
        guard !didStart else { return }
        await withCheckedContinuation { continuation in
            startContinuation = continuation
        }
    }

    func complete(with postID: String?) {
        resolutionContinuation?.resume(returning: postID)
        resolutionContinuation = nil
    }
}

@MainActor
private final class MutablePostNavigationAuthentication: DeepLinkAuthenticating {
    var isAuthenticated: Bool
    var sessionIdentity: AuthSessionIdentity

    init(isAuthenticated: Bool) {
        self.isAuthenticated = isAuthenticated
        sessionIdentity = AuthSessionIdentity(
            token: isAuthenticated ? "initial-session" : nil,
            generation: 0
        )
    }

    func transition(to isAuthenticated: Bool) {
        self.isAuthenticated = isAuthenticated
        sessionIdentity = AuthSessionIdentity(
            token: isAuthenticated ? "replacement-session" : nil,
            generation: sessionIdentity.generation &+ 1
        )
    }

    func completeLoginChallenge(
        token _: String,
        code _: String,
        expectedSession _: AuthSessionIdentity
    ) async throws {
        throw AuthError.verificationFailed
    }
}

struct DeepLinkNavigatorLifecycleTests {
    @Test @MainActor func onlyWebURLsUseUnresolvedURLFallback() throws {
        let malformedCustomURL = try #require(
            URL(string: "hackerspub://%40john@example%40evil.com")
        )
        let unknownCustomURL = try #require(URL(string: "hackerspub://unknown"))
        let webURL = try #require(URL(string: "https://example.com/unhandled"))
        let authentication = MutablePostNavigationAuthentication(isAuthenticated: false)
        let coordinator = NavigationCoordinator()
        let router = ExternalURLRouter()
        var fallbackURLs: [URL] = []
        let dependencies = DeepLinkNavigator.URLDependencies { url in
            fallbackURLs.append(url)
        }

        for url in [malformedCustomURL, unknownCustomURL] {
            #expect(HackersPubURLRouter.resolve(url) == nil)
            #expect(
                DeepLinkNavigator.open(
                    url,
                    authManager: authentication,
                    navigationCoordinator: coordinator,
                    externalURLRouter: router,
                    urlDependencies: dependencies
                ) == nil
            )
        }

        #expect(fallbackURLs.isEmpty)

        #expect(
            DeepLinkNavigator.open(
                webURL,
                authManager: authentication,
                navigationCoordinator: coordinator,
                externalURLRouter: router,
                urlDependencies: dependencies
            ) == nil
        )
        #expect(fallbackURLs == [webURL])
    }

    @Test @MainActor func guestToAuthenticatedTransitionRetargetsSuspendedPostResolution() async throws {
        try await expectPostResolutionToFollowAuthenticationTransition(
            from: false,
            to: true
        )
    }

    @Test @MainActor func authenticatedToGuestTransitionRetargetsSuspendedPostResolution() async throws {
        try await expectPostResolutionToFollowAuthenticationTransition(
            from: true,
            to: false
        )
    }

    @MainActor
    private func expectPostResolutionToFollowAuthenticationTransition(
        from initialAuthentication: Bool,
        to finalAuthentication: Bool
    ) async throws {
        let postID = "resolved-post"
        let staleTab = AppTabSelectionPolicy.defaultTab(
            isAuthenticated: initialAuthentication
        )
        let visibleTab = AppTabSelectionPolicy.defaultTab(
            isAuthenticated: finalAuthentication
        )
        let authentication = MutablePostNavigationAuthentication(
            isAuthenticated: initialAuthentication
        )
        let coordinator = NavigationCoordinator()
        let resolver = SuspendedPostResolution()
        var fallbackOpenCount = 0
        let dependencies = DeepLinkNavigator.PostDependencies(
            resolvePostID: { url in
                await resolver.resolvePostID(for: url)
            },
            openFallback: { _ in
                fallbackOpenCount += 1
            }
        )

        let task = try #require(
            DeepLinkNavigator.open(
                .postURL("https://hackers.pub/@alice/123"),
                authManager: authentication,
                navigationCoordinator: coordinator,
                externalURLRouter: ExternalURLRouter(),
                postDependencies: dependencies
            )
        )
        await resolver.waitUntilStarted()

        #expect(coordinator.currentTab == staleTab)
        #expect(!coordinator.hasPath(for: staleTab))

        authentication.transition(to: finalAuthentication)
        coordinator.setCurrentTab(visibleTab)
        await resolver.complete(with: postID)
        await task.value

        let destination = NavigationDestination.post(id: postID)
        #expect(!coordinator.hasPath(for: staleTab))
        #expect(coordinator.currentTab == visibleTab)
        #expect(coordinator.paths[visibleTab] == [destination])
        #expect(coordinator.path == [destination])
        #expect(fallbackOpenCount == 0)
    }
}
