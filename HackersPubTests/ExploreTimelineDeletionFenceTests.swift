@testable import HackersPub
import Testing

struct ExploreTimelineDeletionFenceTests {
    private struct Edge: ExploreTimelineEdge {
        let cursor: String
        let timelineListID: String
        let postID: String
        let displayedPostID: String?

        init(
            timelineListID: String,
            postID: String? = nil,
            displayedPostID: String? = nil
        ) {
            cursor = "cursor-\(timelineListID)"
            self.timelineListID = timelineListID
            self.postID = postID ?? timelineListID
            self.displayedPostID = displayedPostID
        }

        var postContentListIdentity: PostListItemIdentity {
            PostListItemIdentity(
                rowID: timelineListID,
                postID: postID,
                displayedPostID: displayedPostID
            )
        }
    }

    @Test("SOC-8/POST-11: deletion before a pending page fences non-cooperative completion")
    @MainActor
    func deletionBeforePendingResponseFencesNonCooperativeCompletion() throws {
        let store = ExploreTimelineScopeStore<Edge>()
        let pendingInitial = try #require(store.startInitialLoadIfNeeded())

        let result = store.applyPostContentEvent(.postDeleted(postID: "post-1"))
        let replay = try #require(result.replay)

        #expect(result == .applied(replay: replay))
        #expect(!store.isCurrent(pendingInitial))
        #expect(store.isCurrent(replay))
        #expect(replay.operation == .initial)
        #expect(store.isLoadingInitial)

        _ = store.resolve(
            pendingInitial,
            with: .success(success(page([Edge(timelineListID: "post-1")])))
        )

        #expect(store.edges.isEmpty)

        _ = store.resolve(
            replay,
            with: .success(
                ExploreTimelineFetchResult(
                    page: page([
                        Edge(timelineListID: "post-1"),
                        Edge(timelineListID: "share-post-1", displayedPostID: "post-1"),
                        Edge(timelineListID: "post-2")
                    ]),
                    errorMessage: "Explore network request failed"
                )
            )
        )

        #expect(store.edges.map(\.timelineListID) == ["post-2"])
        #expect(store.hasLoadedInitial)
        #expect(!store.isLoading)
        #expect(store.errorMessage == "Explore network request failed")
    }

    private func page(_ edges: [Edge]) -> ExploreTimelinePage<Edge> {
        ExploreTimelinePage(
            edges: edges,
            pageInfo: ExploreTimelinePageInfo(
                hasPreviousPage: false,
                hasNextPage: false,
                startCursor: edges.first?.cursor,
                endCursor: edges.last?.cursor
            )
        )
    }

    private func success(_ page: ExploreTimelinePage<Edge>) -> ExploreTimelineFetchResult<Edge> {
        ExploreTimelineFetchResult(page: page, errorMessage: nil)
    }
}
