import Foundation
@testable import HackersPub
import Testing

@MainActor
struct SearchServiceTests {
    @Test func uiTestSearchStubReplacesEveryLiveNetworkOperation() async throws {
        let liveNetwork = SearchNetworkSpy()
        let network = SearchNetwork.configured(
            arguments: ["-com.hackerspub.ui-test.search-stub"],
            live: liveNetwork.makeNetwork()
        )
        let service = SearchService(network: network)

        let results = try await service.search(query: "fixture")

        #expect(results.posts.map(\.id) == ["resolved-post-ui-test-post"])
        #expect(results.relatedActors.map(\.id) == ["actor-ui-test-actor"])
        #expect(liveNetwork.postQueries.isEmpty)
        #expect(liveNetwork.actorQueries.isEmpty)
        #expect(liveNetwork.objectQueries.isEmpty)
        #expect(liveNetwork.postURLQueries.isEmpty)
    }

    @Test func relatedActorsComeFromReturnedPostsWithoutPerPostActorRequests() async throws {
        let postMatches = (0 ..< 20).map { index in
            SearchPostMatch(
                result: .resolvedPost(id: "post-\(index)", url: "https://example.com/posts/\(index)"),
                actor: SearchActor(
                    id: "actor-\(index)",
                    name: "Actor \(index)",
                    handle: "@actor\(index)@example.com",
                    avatarURL: "https://example.com/avatars/\(index).png"
                )
            )
        }
        let network = SearchNetworkSpy(posts: postMatches)
        let service = SearchService(network: network.makeNetwork())

        let results = try await service.search(query: "swift")

        #expect(network.postQueries == ["swift"])
        #expect(network.actorQueries == ["swift"])
        #expect(network.objectQueries == ["swift"])
        #expect(network.postURLQueries.isEmpty)
        #expect(results.relatedActors.count == 20)
        #expect(results.sectionFailures.isEmpty)
    }

    @Test func objectURLUsesAtMostOnePostByURLResolution() async throws {
        let url = "https://remote.example/posts/one"
        let network = SearchNetworkSpy(objectURL: url, postID: "resolved-post")
        let service = SearchService(network: network.makeNetwork())

        let results = try await service.search(query: url)

        #expect(network.postURLQueries == [url])
        #expect(results.posts.map(\.id) == ["resolved-post-resolved-post"])
    }

    @Test func resolvedPostUsesCanonicalIdentityToAvoidDuplicatingAnInBandPost() async throws {
        let directPost = SearchPostMatch(
            result: .resolvedPost(id: "rendered-direct-post", url: "https://example.com/posts/shared"),
            actor: SearchActor(
                id: "actor",
                name: "Actor",
                handle: "@actor@example.com",
                avatarURL: "https://example.com/avatar.png"
            ),
            postIdentity: "shared-post"
        )
        let laterPost = SearchPostMatch(
            result: .resolvedPost(id: "rendered-later-post", url: "https://example.com/posts/later"),
            actor: SearchActor(
                id: "later-actor",
                name: "Later actor",
                handle: "@later@example.com",
                avatarURL: "https://example.com/later-avatar.png"
            ),
            postIdentity: "later-post"
        )
        let network = SearchNetworkSpy(
            posts: [directPost, laterPost],
            objectURL: "https://example.com/posts/shared",
            postID: "shared-post"
        )
        let service = SearchService(network: network.makeNetwork())

        let results = try await service.search(query: "shared")

        #expect(results.posts.map(\.id) == [
            "resolved-post-rendered-direct-post",
            "resolved-post-rendered-later-post"
        ])
        #expect(network.postURLQueries == ["https://example.com/posts/shared"])
    }

    @Test func actorSearchFailureKeepsSuccessfulPostResultsAndMarksOnlyAccounts() async throws {
        let post = SearchPostMatch(
            result: .resolvedPost(id: "post", url: "https://example.com/posts/post"),
            actor: SearchActor(
                id: "actor",
                name: "Actor",
                handle: "@actor@example.com",
                avatarURL: "https://example.com/avatar.png"
            )
        )
        let network = SearchNetworkSpy(posts: [post], actorError: SearchServiceFailure.offline)
        let service = SearchService(network: network.makeNetwork())

        let results = try await service.search(query: "swift")

        #expect(results.posts.map(\.id) == ["resolved-post-post"])
        #expect(results.relatedActors.map(\.id) == ["actor-actor"])
        #expect(results.sectionFailures[.accounts] == "offline")
        #expect(results.sectionFailures[.posts] == nil)
    }

    @Test func guestSearchSkipsUnavailableActorEnrichmentAndKeepsPostResults() async throws {
        let post = SearchPostMatch(
            result: .resolvedPost(id: "post", url: "https://example.com/posts/post"),
            actor: SearchActor(
                id: "actor",
                name: "Actor",
                handle: "@actor@example.com",
                avatarURL: "https://example.com/avatar.png"
            )
        )
        let network = SearchNetworkSpy(
            posts: [post],
            objectURL: "https://hackers.pub/@missing",
            actorError: SearchServiceFailure.offline,
            canSearchActors: false
        )
        let service = SearchService(network: network.makeNetwork())

        let results = try await service.search(query: "missing")

        #expect(network.actorQueries.isEmpty)
        #expect(results.posts.map(\.id) == ["resolved-post-post"])
        #expect(results.relatedActors.map(\.id) == ["actor-actor"])
        #expect(results.directActors.isEmpty)
        #expect(results.sectionFailures[.accounts] == nil)
    }

    @Test func authenticatedSearchUsesActorEnrichmentForDirectAndResolvedProfiles() async throws {
        let actor = SearchActor(
            id: "actor",
            name: "Actor",
            handle: "@actor@example.com",
            avatarURL: "https://example.com/avatar.png"
        )
        let network = SearchNetworkSpy(
            directActors: [actor],
            objectURL: "https://hackers.pub/@actor@example.com"
        )
        let service = SearchService(network: network.makeNetwork())

        let results = try await service.search(query: "actor")

        #expect(Set(network.actorQueries) == ["actor", "actor@example.com"])
        #expect(results.directActors.map(\.id) == ["actor-actor"])
        #expect(results.sectionFailures[.accounts] == nil)
    }

    @Test func guestCancellationDoesNotStartActorEnrichmentBeforeLatePostsComplete() async {
        let network = SuspendedGuestSearchNetwork()
        let service = SearchService(network: network.makeNetwork())

        let search = Task {
            try await service.search(query: "guest")
        }
        let didStart = await network.waitForPostRequest()
        #expect(didStart)
        guard didStart else {
            search.cancel()
            network.cancelPosts()
            return
        }
        search.cancel()
        network.completePosts()

        var wasCancelled = false
        do {
            _ = try await search.value
        } catch is CancellationError {
            wasCancelled = true
        } catch {
            Issue.record("Expected cancellation, received \(error)")
        }

        #expect(wasCancelled)
        #expect(network.actorQueries.isEmpty)
    }

    @Test func guestPostRequestStartWaitIsBoundedWhenNoSearchStarts() async {
        let network = SuspendedGuestSearchNetwork()

        let didStart = await network.waitForPostRequest(timeout: .zero)

        #expect(!didStart)
    }

    @Test func liveSearchUsesTheBoundedBatchAndSingleURLQueries() throws {
        let source = try source(named: "SearchService.swift")

        #expect(source.contains("SearchActorsByHandleQuery"))
        #expect(source.contains("PostByUrlQuery"))
        #expect(!source.contains("ActorByHandleQuery"))
        #expect(!source.contains("DeepLinkPostResolver"))
    }

    private func source(named filename: String) throws -> String {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(
            contentsOf: repositoryRoot.appendingPathComponent("HackersPub/Views/\(filename)"),
            encoding: .utf8
        )
    }
}

@MainActor
private final class SearchNetworkSpy {
    private let posts: [SearchPostMatch]
    private let directActors: [SearchActor]
    private let objectURL: String?
    private let postID: String?
    private let actorError: (any Error)?
    private let canSearchActors: Bool

    private(set) var postQueries: [String] = []
    private(set) var actorQueries: [String] = []
    private(set) var objectQueries: [String] = []
    private(set) var postURLQueries: [String] = []

    init(
        posts: [SearchPostMatch] = [],
        directActors: [SearchActor] = [],
        objectURL: String? = nil,
        postID: String? = nil,
        actorError: (any Error)? = nil,
        canSearchActors: Bool = true
    ) {
        self.posts = posts
        self.directActors = directActors
        self.objectURL = objectURL
        self.postID = postID
        self.actorError = actorError
        self.canSearchActors = canSearchActors
    }

    func makeNetwork() -> SearchNetwork {
        SearchNetwork(
            searchPosts: { [unowned self] query in
                self.postQueries.append(query)
                return self.posts
            },
            searchActors: { [unowned self] query in
                self.actorQueries.append(query)
                if let actorError = self.actorError {
                    throw actorError
                }
                return self.directActors
            },
            searchObjectURL: { [unowned self] query in
                self.objectQueries.append(query)
                return self.objectURL
            },
            resolvePostID: { [unowned self] url in
                self.postURLQueries.append(url)
                return self.postID
            },
            canSearchActors: { [unowned self] in self.canSearchActors }
        )
    }
}

private enum SearchServiceFailure: LocalizedError {
    case offline

    var errorDescription: String? {
        "offline"
    }
}

@MainActor
private final class SuspendedGuestSearchNetwork {
    private var postContinuation: CheckedContinuation<[SearchPostMatch], any Error>?
    private var isPostCancellationRequested = false
    private(set) var actorQueries: [String] = []

    func makeNetwork() -> SearchNetwork {
        SearchNetwork(
            searchPosts: { [unowned self] _ in
                try await self.loadPosts()
            },
            searchActors: { [unowned self] query in
                self.actorQueries.append(query)
                return []
            },
            searchObjectURL: { _ in nil },
            resolvePostID: { _ in nil },
            canSearchActors: { false }
        )
    }

    func waitForPostRequest(timeout: Duration = .seconds(1)) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while postContinuation == nil {
            guard clock.now < deadline else { return false }
            await Task.yield()
        }
        return true
    }

    func cancelPosts() {
        isPostCancellationRequested = true
        postContinuation?.resume(throwing: CancellationError())
        postContinuation = nil
    }

    func completePosts() {
        postContinuation?.resume(returning: [])
        postContinuation = nil
    }

    private func loadPosts() async throws -> [SearchPostMatch] {
        if isPostCancellationRequested {
            throw CancellationError()
        }
        return try await withCheckedThrowingContinuation { continuation in
            if isPostCancellationRequested {
                continuation.resume(throwing: CancellationError())
            } else {
                postContinuation = continuation
            }
        }
    }
}
