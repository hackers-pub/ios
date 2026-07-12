import Foundation
@testable import HackersPub
import Testing

struct ActorProfilePostRequestCoordinatorTests {
    @Test func sameProfileReappearancePreservesTheLoadedIdentityAndGeneration() {
        var coordinator = ActorProfilePostRequestCoordinator(
            profileID: "actor-a",
            hasLoadedInitial: true
        )
        let generation = coordinator.generation

        let didActivate = coordinator.activate(profileID: "actor-a", hasLoadedInitial: true)
        #expect(!didActivate)
        #expect(coordinator.profileID == "actor-a")
        #expect(coordinator.generation == generation)
        #expect(coordinator.hasLoadedInitial)
    }

    @Test func changingProfileIdentityInvalidatesOldPagesAndRequestsANewInitialLoad() throws {
        var coordinator = ActorProfilePostRequestCoordinator(
            profileID: "actor-a",
            hasLoadedInitial: true
        )
        let optionalOldLoadMore = coordinator.beginLoadMore()
        let oldLoadMore = try #require(optionalOldLoadMore)

        let didActivate = coordinator.activate(profileID: "actor-b", hasLoadedInitial: false)
        #expect(didActivate)
        #expect(!coordinator.isCurrent(oldLoadMore))
        #expect(!coordinator.hasLoadedInitial)

        let optionalInitial = coordinator.beginInitialLoadIfNeeded()
        let initial = try #require(optionalInitial)
        #expect(initial.profileID == "actor-b")
        #expect(initial.kind == .initial)
    }

    @Test func anAuthoritativeRefreshRejectsAnOlderLoadMoreCompletion() throws {
        var coordinator = ActorProfilePostRequestCoordinator(
            profileID: "actor-a",
            hasLoadedInitial: true
        )
        let optionalLoadMore = coordinator.beginLoadMore()
        let loadMore = try #require(optionalLoadMore)
        let optionalRefresh = coordinator.beginRefresh()
        let refresh = try #require(optionalRefresh)

        #expect(!coordinator.isCurrent(loadMore))
        #expect(coordinator.isCurrent(refresh))
        let didFinishStaleLoadMore = coordinator.finish(loadMore, didLoadInitial: false)
        let didFinishRefresh = coordinator.finish(refresh, didLoadInitial: false)
        #expect(!didFinishStaleLoadMore)
        #expect(didFinishRefresh)
    }

    @Test func loadMoreIsSingleFlightAndReopensAfterItsCurrentCompletion() throws {
        var coordinator = ActorProfilePostRequestCoordinator(
            profileID: "actor-a",
            hasLoadedInitial: true
        )
        let optionalFirst = coordinator.beginLoadMore()
        let first = try #require(optionalFirst)

        let secondLoadMore = coordinator.beginLoadMore()
        let loadNewerWhileMoreIsActive = coordinator.beginLoadNewer()
        #expect(secondLoadMore == nil)
        #expect(loadNewerWhileMoreIsActive == nil)
        let didFinishFirst = coordinator.finish(first, didLoadInitial: false)
        #expect(didFinishFirst)

        let optionalNext = coordinator.beginLoadMore()
        let next = try #require(optionalNext)
        #expect(next.generation == first.generation)
        #expect(next != first)
    }

    @Test func aNoProgressLoadMorePageClosesTheCursorToPreventAnInfiniteLoop() {
        var pageState = ActorProfileTabPageState(
            hasLoaded: true,
            isLoading: false,
            hasPreviousPage: false,
            hasNextPage: true,
            startCursor: "newest",
            endCursor: "oldest",
            errorMessage: nil
        )

        let didMakeProgress = pageState.applyLoadMorePage(
            appendedCount: 0,
            nextEndCursor: "oldest",
            hasNextPage: true
        )
        #expect(!didMakeProgress)
        #expect(!pageState.hasNextPage)
        #expect(pageState.endCursor == "oldest")
    }

    @Test func aCursorAdvanceWithoutVisibleRowsStillAllowsTheNextPage() {
        var pageState = ActorProfileTabPageState(
            hasLoaded: true,
            isLoading: false,
            hasPreviousPage: false,
            hasNextPage: true,
            startCursor: "newest",
            endCursor: "oldest",
            errorMessage: nil
        )

        let didMakeProgress = pageState.applyLoadMorePage(
            appendedCount: 0,
            nextEndCursor: "older",
            hasNextPage: true
        )
        #expect(didMakeProgress)
        #expect(pageState.hasNextPage)
        #expect(pageState.endCursor == "older")
    }

    @Test func actorProfileViewWiresIdentityTasksAndGenerationGuardsIntoLiveRequests() throws {
        let viewSource = try actorProfileViewSource()
        let loadingSource = try actorProfilePostLoadingSource()
        let refresh = try #require(loadingSource.block(after: "func refreshProfile() async"))
        let refreshPosts = try #require(loadingSource.block(after: "private func refreshPosts("))
        let loadMore = try #require(loadingSource.block(after: "func loadMorePosts() async"))

        #expect(viewSource.contains(".task(id: actor.id)"))
        #expect(!viewSource.contains(".task {\n            await fetchProfile(cachePolicy: .networkFirst)"))
        #expect(viewSource.contains("profilePostsRequestCoordinator.activate"))
        #expect(refresh.contains("profilePostsRequestCoordinator.beginRefresh"))
        #expect(refreshPosts.contains("profilePostsRequestCoordinator.isCurrent"))
        #expect(refreshPosts.contains("if posts.isEmpty || postsPageState.startCursor == nil"))
        #expect(refreshPosts.contains("try await fetchNewerPosts(for: request)"))
        #expect(loadMore.contains("profilePostsRequestCoordinator.beginLoadMore"))
        #expect(loadMore.contains("applyLoadMorePage"))
    }

    private func actorProfileViewSource() throws -> String {
        try profileSource(named: "ActorProfileView.swift")
    }

    private func actorProfilePostLoadingSource() throws -> String {
        try profileSource(named: "ActorProfilePostLoading.swift")
    }

    private func profileSource(named fileName: String) throws -> String {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = repositoryRoot
            .appendingPathComponent("HackersPub")
            .appendingPathComponent("Views")
            .appendingPathComponent("Profile")
            .appendingPathComponent(fileName)
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }
}

private extension String {
    func block(after marker: String) -> String? {
        guard let markerRange = range(of: marker) else {
            return nil
        }
        guard let openingBrace = self[markerRange.upperBound...].firstIndex(of: "{") else {
            return nil
        }

        var depth = 0
        var index = openingBrace
        while index < endIndex {
            switch self[index] {
            case "{":
                depth += 1
            case "}":
                depth -= 1
                if depth == 0 {
                    return String(self[openingBrace ... index])
                }
            default:
                break
            }
            index = self.index(after: index)
        }
        return nil
    }
}
