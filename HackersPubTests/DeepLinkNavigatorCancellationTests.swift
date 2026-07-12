import Foundation
@testable import HackersPub
import Testing

private actor SuspendedPostByURLLookup {
    private var didStart = false
    private var startContinuation: CheckedContinuation<Void, Never>?
    private(set) var observedCancellationError = false

    func fetchPostID(for _: String) async throws -> String? {
        didStart = true
        startContinuation?.resume()
        startContinuation = nil

        do {
            try await Task.sleep(nanoseconds: 60_000_000_000)
            return nil
        } catch {
            observedCancellationError = error is CancellationError
            throw error
        }
    }

    func waitUntilStarted() async {
        guard !didStart else { return }
        await withCheckedContinuation { continuation in
            startContinuation = continuation
        }
    }
}

@MainActor
private final class PostNavigationAuthenticationStub: DeepLinkAuthenticating {
    let isAuthenticated = false
    let sessionIdentity = AuthSessionIdentity(token: nil, generation: 0)

    func completeLoginChallenge(
        token _: String,
        code _: String,
        expectedSession _: AuthSessionIdentity
    ) async throws {
        throw AuthError.verificationFailed
    }
}

struct DeepLinkNavigatorCancellationTests {
    @Test @MainActor func propagatesCancellationWithoutOpeningFallback() async throws {
        let url = try #require(URL(string: "https://hackers.pub/@alice/123"))
        let resolver = SuspendedPostByURLLookup()
        let coordinator = NavigationCoordinator()
        let router = ExternalURLRouter()
        var fallbackOpenCount = 0
        let dependencies = DeepLinkNavigator.PostDependencies(
            resolvePostID: { url in
                try await DeepLinkPostResolver.resolvePostID(
                    for: url,
                    fetchPostByURL: { url in
                        try await resolver.fetchPostID(for: url)
                    }
                )
            },
            openFallback: { _ in
                fallbackOpenCount += 1
            }
        )

        let task = try #require(
            DeepLinkNavigator.open(
                .postURL(url.absoluteString),
                authManager: PostNavigationAuthenticationStub(),
                navigationCoordinator: coordinator,
                externalURLRouter: router,
                postDependencies: dependencies
            )
        )
        await resolver.waitUntilStarted()

        task.cancel()
        await task.value

        #expect(await resolver.observedCancellationError)
        #expect(fallbackOpenCount == 0)
        #expect(router.destination == nil)
        #expect(!coordinator.hasPath(for: .local))
    }
}
