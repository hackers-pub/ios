import Foundation
@testable import HackersPub
import Testing

@MainActor
struct SearchPostContentDeletionTests {
    @Test func resolvedPostDeletionUsesProductionRowIdentityAndBlocksLateRestoration() async {
        let requests = ControlledResolvedPostSearchRequest()
        let session = SearchSession(request: requests.load, debounce: .zero)
        let resolvedPost = SearchResultType.resolvedPost(
            id: "deleted",
            url: "https://example.com/deleted"
        )

        session.inputChanged("stable")
        let startedInitialRequest = await requests.waitForRequestCount(1)
        #expect(startedInitialRequest)
        guard startedInitialRequest else { return }
        requests.succeed(request: 0, with: resolvedPost)
        await waitUntil { session.posts == [resolvedPost] }

        let actor = SearchResultType.actor(
            SearchActor(id: "actor", name: nil, handle: "@actor", avatarURL: "")
        )
        #expect(actor.postContentListIdentity == nil)

        let rows = [resolvedPost].compactMap(\.postContentListIdentity)
        #expect(rows == [
            PostListItemIdentity(
                rowID: "resolved-post-deleted",
                postID: "deleted",
                displayedPostID: nil
            )
        ])
        let action = PostContentListEventRouter.route(
            .postDeleted(postID: "deleted"),
            host: .search,
            rows: rows,
            eventGeneration: 0,
            activeGeneration: 0
        )
        #expect(action == .remove(rowIDs: [resolvedPost.id]))

        guard case let .remove(rowIDs) = action else { return }
        session.inputChanged("refresh")
        let startedRefreshRequest = await requests.waitForRequestCount(2)
        #expect(startedRefreshRequest)
        guard startedRefreshRequest else { return }
        session.removePosts(withRowIDs: rowIDs)

        requests.succeed(request: 1, with: resolvedPost)
        await Task.yield()

        #expect(session.posts.isEmpty)
        #expect(!session.isLoading)
    }

    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0 ..< 100 {
            if condition() {
                return
            }
            await Task.yield()
        }
    }
}

@MainActor
private final class ControlledResolvedPostSearchRequest {
    private var continuations: [CheckedContinuation<SearchResults, any Error>] = []
    private(set) var requestedQueries: [String] = []

    func load(query: String) async throws -> SearchResults {
        requestedQueries.append(query)
        return try await withCheckedThrowingContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func waitForRequestCount(_ count: Int) async -> Bool {
        for _ in 0 ..< 100 {
            if requestedQueries.count >= count {
                return true
            }
            await Task.yield()
        }
        return requestedQueries.count >= count
    }

    func succeed(request: Int, with result: SearchResultType) {
        continuations[request].resume(returning: SearchResults(posts: [result]))
    }
}
