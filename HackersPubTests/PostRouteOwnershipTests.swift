import Foundation
@testable import HackersPub
import Testing

private enum ControlledPostResolutionError: Error {
    case failed
}

private actor ControlledPostResolver {
    private var startedURLs: [String] = []
    private var startContinuations: [String: [CheckedContinuation<Void, Never>]] = [:]
    private var continuations: [String: [CheckedContinuation<String?, Error>]] = [:]

    func resolve(_ url: String) async throws -> String? {
        startedURLs.append(url)
        if var waiters = startContinuations[url], !waiters.isEmpty {
            waiters.removeFirst().resume()
            startContinuations[url] = waiters
        }

        return try await withCheckedThrowingContinuation { continuation in
            continuations[url, default: []].append(continuation)
        }
    }

    func waitUntilStarted(_ url: String, count: Int) async {
        guard startedURLs.filter({ $0 == url }).count < count else { return }
        await withCheckedContinuation { continuation in
            startContinuations[url, default: []].append(continuation)
        }
    }

    func succeed(_ url: String, with postID: String?) {
        resumeNext(url, with: .success(postID))
    }

    func fail(_ url: String) {
        resumeNext(url, with: .failure(ControlledPostResolutionError.failed))
    }

    private func resumeNext(_ url: String, with result: Result<String?, Error>) {
        guard var waiters = continuations[url], !waiters.isEmpty else { return }
        let continuation = waiters.removeFirst()
        continuations[url] = waiters
        continuation.resume(with: result)
    }
}

@MainActor
private final class PostRouteAuthenticationStub: DeepLinkAuthenticating {
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

@MainActor
private func openPostRoute(
    _ url: String,
    authentication: PostRouteAuthenticationStub,
    navigationCoordinator: NavigationCoordinator,
    postDependencies: DeepLinkNavigator.PostDependencies
) -> Task<Void, Never>? {
    DeepLinkNavigator.open(
        .postURL(url),
        authManager: authentication,
        navigationCoordinator: navigationCoordinator,
        externalURLRouter: ExternalURLRouter(),
        postDependencies: postDependencies
    )
}

struct PostRouteOwnershipTests {
    @Test @MainActor func onlyTheLatestPostRouteCanNavigateOrOpenFallbackAcrossABA() async throws {
        let firstA = "https://hackers.pub/@alice/first"
        let secondURL = "https://hackers.pub/@bob/second"
        let secondA = firstA
        let resolver = ControlledPostResolver()
        let authentication = PostRouteAuthenticationStub()
        let coordinator = NavigationCoordinator()
        var fallbackURLs: [String] = []
        let dependencies = DeepLinkNavigator.PostDependencies(
            resolvePostID: { url in try await resolver.resolve(url) },
            openFallback: { fallbackURLs.append($0) }
        )

        let firstTask = try #require(
            openPostRoute(
                firstA,
                authentication: authentication,
                navigationCoordinator: coordinator,
                postDependencies: dependencies
            )
        )
        await resolver.waitUntilStarted(firstA, count: 1)

        let secondTask = try #require(
            openPostRoute(
                secondURL,
                authentication: authentication,
                navigationCoordinator: coordinator,
                postDependencies: dependencies
            )
        )
        await resolver.waitUntilStarted(secondURL, count: 1)
        #expect(firstTask.isCancelled)

        await resolver.succeed(secondURL, with: "post-b")
        await secondTask.value
        #expect(coordinator.paths[.local] == [.post(id: "post-b")])

        let thirdTask = try #require(
            openPostRoute(
                secondA,
                authentication: authentication,
                navigationCoordinator: coordinator,
                postDependencies: dependencies
            )
        )
        await resolver.waitUntilStarted(secondA, count: 2)

        await resolver.fail(firstA)
        await firstTask.value
        #expect(fallbackURLs.isEmpty)
        #expect(coordinator.paths[.local] == [.post(id: "post-b")])

        await resolver.succeed(secondA, with: "post-a")
        await thirdTask.value
        #expect(coordinator.paths[.local] == [.post(id: "post-b"), .post(id: "post-a")])
    }

    @Test @MainActor func onlyTheLatestPostRouteCanOpenNilFallback() async throws {
        let staleURL = "https://hackers.pub/@alice/stale"
        let latestURL = "https://hackers.pub/@bob/latest"
        let resolver = ControlledPostResolver()
        let authentication = PostRouteAuthenticationStub()
        let coordinator = NavigationCoordinator()
        var fallbackURLs: [String] = []
        let dependencies = DeepLinkNavigator.PostDependencies(
            resolvePostID: { url in try await resolver.resolve(url) },
            openFallback: { fallbackURLs.append($0) }
        )

        let staleTask = try #require(
            DeepLinkNavigator.open(
                .postURL(staleURL),
                authManager: authentication,
                navigationCoordinator: coordinator,
                externalURLRouter: ExternalURLRouter(),
                postDependencies: dependencies
            )
        )
        await resolver.waitUntilStarted(staleURL, count: 1)

        let latestTask = try #require(
            DeepLinkNavigator.open(
                .postURL(latestURL),
                authManager: authentication,
                navigationCoordinator: coordinator,
                externalURLRouter: ExternalURLRouter(),
                postDependencies: dependencies
            )
        )
        await resolver.waitUntilStarted(latestURL, count: 1)

        await resolver.succeed(staleURL, with: nil)
        await staleTask.value
        #expect(fallbackURLs.isEmpty)

        await resolver.succeed(latestURL, with: nil)
        await latestTask.value
        #expect(fallbackURLs == [latestURL])
    }

    @Test @MainActor func onlyTheLatestPostRouteCanOpenErrorFallback() async throws {
        let staleURL = "https://hackers.pub/@alice/stale"
        let latestURL = "https://hackers.pub/@bob/latest"
        let resolver = ControlledPostResolver()
        let authentication = PostRouteAuthenticationStub()
        let coordinator = NavigationCoordinator()
        var fallbackURLs: [String] = []
        let dependencies = DeepLinkNavigator.PostDependencies(
            resolvePostID: { url in try await resolver.resolve(url) },
            openFallback: { fallbackURLs.append($0) }
        )

        let staleTask = try #require(
            DeepLinkNavigator.open(
                .postURL(staleURL),
                authManager: authentication,
                navigationCoordinator: coordinator,
                externalURLRouter: ExternalURLRouter(),
                postDependencies: dependencies
            )
        )
        await resolver.waitUntilStarted(staleURL, count: 1)

        let latestTask = try #require(
            DeepLinkNavigator.open(
                .postURL(latestURL),
                authManager: authentication,
                navigationCoordinator: coordinator,
                externalURLRouter: ExternalURLRouter(),
                postDependencies: dependencies
            )
        )
        await resolver.waitUntilStarted(latestURL, count: 1)

        await resolver.fail(staleURL)
        await staleTask.value
        #expect(fallbackURLs.isEmpty)

        await resolver.fail(latestURL)
        await latestTask.value
        #expect(fallbackURLs == [latestURL])
    }
}
