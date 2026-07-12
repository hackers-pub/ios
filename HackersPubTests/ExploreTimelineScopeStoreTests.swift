import CoreGraphics
import Foundation
@testable import HackersPub
import Testing

struct ExploreTimelineScopeStoreTests {
    private struct Edge: ExploreTimelineEdge, Equatable {
        let cursor: String
        let timelineListID: String
        let postID: String
        let displayedPostID: String?

        init(
            cursor: String,
            timelineListID: String,
            postID: String? = nil,
            displayedPostID: String? = nil
        ) {
            self.cursor = cursor
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

    @Test("SOC-14: each Explore scope retains its rows, cursors, and scroll anchor")
    @MainActor
    func scopeStoresKeepIndependentPresentationState() throws {
        let local = ExploreTimelineScopeStore<Edge>()
        let global = ExploreTimelineScopeStore<Edge>()
        let localPage = ExploreTimelinePage(
            edges: [Edge(cursor: "local-cursor", timelineListID: "local-post")],
            pageInfo: ExploreTimelinePageInfo(
                hasPreviousPage: false,
                hasNextPage: true,
                startCursor: "local-start",
                endCursor: "local-end"
            )
        )
        let globalPage = ExploreTimelinePage(
            edges: [Edge(cursor: "global-cursor", timelineListID: "global-post")],
            pageInfo: ExploreTimelinePageInfo(
                hasPreviousPage: false,
                hasNextPage: false,
                startCursor: "global-start",
                endCursor: "global-end"
            )
        )

        let localRequest = try #require(local.startInitialLoadIfNeeded())
        _ = local.resolve(localRequest, with: .success(success(localPage)))
        local.scrollViewport = FeedViewportSnapshot(
            visibleAnchors: [FeedViewportAnchor(id: "local-post", offset: -12)],
            isAtTop: false
        )
        let globalRequest = try #require(global.startInitialLoadIfNeeded())
        _ = global.resolve(globalRequest, with: .success(success(globalPage)))
        global.scrollViewport = FeedViewportSnapshot(
            visibleAnchors: [FeedViewportAnchor(id: "global-post", offset: -7)],
            isAtTop: false
        )

        #expect(local.startInitialLoadIfNeeded() == nil)
        #expect(local.edges == localPage.edges)
        #expect(local.endCursor == "local-end")
        #expect(local.scrollViewport.primaryAnchor?.id == "local-post")
        #expect(local.scrollViewport.primaryAnchor?.offset == -12)
        #expect(global.edges == globalPage.edges)
        #expect(global.endCursor == "global-end")
        #expect(global.scrollViewport.primaryAnchor?.id == "global-post")
        #expect(global.scrollViewport.primaryAnchor?.offset == -7)
    }

    @Test("SOC-14: newer pages prepend without duplicating a timeline identity")
    @MainActor
    func mergeNewerPageKeepsScopeCursorStateConsistent() {
        let store = ExploreTimelineScopeStore<Edge>()
        store.replaceInitial(
            with: ExploreTimelinePage(
                edges: [Edge(cursor: "cursor-2", timelineListID: "post-2")],
                pageInfo: ExploreTimelinePageInfo(
                    hasPreviousPage: false,
                    hasNextPage: true,
                    startCursor: "cursor-2",
                    endCursor: "cursor-2"
                )
            )
        )

        let newestEdge = Edge(cursor: "cursor-1", timelineListID: "post-1")
        let duplicateEdge = Edge(cursor: "cursor-2-reissued", timelineListID: "post-2")
        store.mergeNewer(
            ExploreTimelinePage(
                edges: [newestEdge, duplicateEdge],
                pageInfo: ExploreTimelinePageInfo(
                    hasPreviousPage: true,
                    hasNextPage: true,
                    startCursor: "cursor-1",
                    endCursor: "cursor-2-reissued"
                )
            )
        )

        #expect(store.edges.map(\.timelineListID) == ["post-1", "post-2"])
        #expect(store.startCursor == "cursor-1")
        #expect(store.pendingNewerCursor == "cursor-1")
        #expect(store.hasPreviousPage)
    }

    @Test("SOC-14: a refresh requested during initial load replays after that generation resolves")
    @MainActor
    func refreshDuringInitialLoadReplays() throws {
        let store = ExploreTimelineScopeStore<Edge>()
        let initial = try #require(store.startInitialLoadIfNeeded())

        #expect(store.requestRefresh() == nil)
        let replay = try #require(store.resolve(initial, with: .success(success(page(ids: ["post-2"])))))

        #expect(replay.operation == .newer("start-post-2"))
        #expect(store.isLoading)
        _ = store.resolve(replay, with: .success(success(page(ids: ["post-1"]))))
        #expect(store.edges.map(\.timelineListID) == ["post-1", "post-2"])
    }

    @Test("SOC-14: repeated busy refreshes coalesce to one replay generation")
    @MainActor
    func repeatedBusyRefreshesCoalesce() throws {
        let store = ExploreTimelineScopeStore<Edge>()
        let initial = try #require(store.startInitialLoadIfNeeded())

        #expect(store.requestRefresh() == nil)
        #expect(store.requestRefresh() == nil)
        #expect(store.requestRefresh() == nil)
        let replay = try #require(store.resolve(initial, with: .success(success(page(ids: ["post-2"])))))

        #expect(replay.generation > initial.generation)
        #expect(store.requestRefresh() == nil)
        let finalReplay = store.resolve(replay, with: .success(success(page(ids: ["post-1"]))))
        #expect(finalReplay != nil)
        #expect(finalReplay?.generation ?? 0 > replay.generation)
        #expect(try store.resolve(#require(finalReplay), with: .success(success(page(ids: [])))) == nil)
    }

    @Test("SOC-14: initial cancellation is silent and a later visible lifetime can retry")
    @MainActor
    func cancellationDoesNotPermanentlyMarkInitialLoadComplete() throws {
        let store = ExploreTimelineScopeStore<Edge>()
        let initial = try #require(store.startInitialLoadIfNeeded())

        #expect(store.resolve(initial, with: .failure(CancellationError())) == nil)
        #expect(!store.hasLoadedInitial)
        #expect(!store.isLoading)
        #expect(store.errorMessage == nil)
        #expect(store.startInitialLoadIfNeeded()?.operation == .initial)
    }

    @Test("SOC-14: A to B to A discards A's stale success while each scope remains independent")
    @MainActor
    func scopeSwitchInvalidatesOnlyTheHiddenScope() throws {
        let local = ExploreTimelineScopeStore<Edge>()
        let global = ExploreTimelineScopeStore<Edge>()
        let staleLocal = try #require(local.startInitialLoadIfNeeded())
        local.cancelVisibleWork()

        let globalInitial = try #require(global.startInitialLoadIfNeeded())
        _ = global.resolve(globalInitial, with: .success(success(page(ids: ["global-post"]))))
        let currentLocal = try #require(local.startInitialLoadIfNeeded())
        _ = local.resolve(staleLocal, with: .success(success(page(ids: ["stale-local"]))))
        _ = local.resolve(currentLocal, with: .success(success(page(ids: ["local-post"]))))

        #expect(local.edges.map(\.timelineListID) == ["local-post"])
        #expect(global.edges.map(\.timelineListID) == ["global-post"])
    }

    @Test("SOC-14: stale older-generation successes and errors cannot overwrite the current scope")
    @MainActor
    func staleSuccessAndErrorAreIgnored() throws {
        let store = ExploreTimelineScopeStore<Edge>()
        let initial = try #require(store.startInitialLoadIfNeeded())
        _ = store.resolve(initial, with: .success(success(page(ids: ["post-2"], hasNextPage: true))))
        let older = try #require(store.requestOlderPage())
        store.cancelVisibleWork()
        let refresh = try #require(store.requestRefresh())

        _ = store.resolve(older, with: .success(success(page(ids: ["stale-older"]))))
        _ = store.resolve(older, with: .failure(TestError()))
        _ = store.resolve(refresh, with: .success(success(page(ids: ["post-1"]))))

        #expect(store.edges.map(\.timelineListID) == ["post-1", "post-2"])
        #expect(store.errorMessage == nil)
    }

    @Test("TL-7/TL-8: an error with no timeline data remains visible instead of becoming a blank feed")
    @MainActor
    func noDataErrorIsVisible() throws {
        let store = ExploreTimelineScopeStore<Edge>()
        let initial = try #require(store.startInitialLoadIfNeeded())

        _ = store.resolve(
            initial,
            with: .success(ExploreTimelineFetchResult(page: nil, errorMessage: "GraphQL timeline error"))
        )

        #expect(store.edges.isEmpty)
        #expect(store.errorMessage == "GraphQL timeline error")
        #expect(!store.hasLoadedInitial)
    }

    @Test("TL-8: successful empty and partial GraphQL responses retain their distinct presentation states")
    @MainActor
    func emptyAndPartialResponsesArePreserved() throws {
        let emptyStore = ExploreTimelineScopeStore<Edge>()
        let emptyInitial = try #require(emptyStore.startInitialLoadIfNeeded())
        _ = emptyStore.resolve(emptyInitial, with: .success(success(page(ids: []))))

        #expect(emptyStore.hasLoadedInitial)
        #expect(emptyStore.edges.isEmpty)
        #expect(emptyStore.errorMessage == nil)

        let partialStore = ExploreTimelineScopeStore<Edge>()
        let partialInitial = try #require(partialStore.startInitialLoadIfNeeded())
        _ = partialStore.resolve(
            partialInitial,
            with: .success(
                ExploreTimelineFetchResult(
                    page: page(ids: ["post-1"]),
                    errorMessage: "Some timeline fields could not be loaded"
                )
            )
        )

        #expect(partialStore.edges.map(\.timelineListID) == ["post-1"])
        #expect(partialStore.errorMessage == "Some timeline fields could not be loaded")
    }

    @Test("TL-12: each request kind exposes only its own loading state")
    @MainActor
    func directionalLoadingStateIsIndependent() throws {
        let store = ExploreTimelineScopeStore<Edge>()
        let initial = try #require(store.startInitialLoadIfNeeded())
        #expect(store.isLoadingInitial)
        #expect(!store.isLoadingOlder)
        #expect(!store.isLoadingNewer)

        _ = store.resolve(initial, with: .success(success(page(ids: ["post-2"], hasNextPage: true))))
        let older = try #require(store.requestOlderPage())
        #expect(!store.isLoadingInitial)
        #expect(store.isLoadingOlder)
        #expect(!store.isLoadingNewer)

        _ = store.resolve(older, with: .success(success(page(ids: []))))
        let newer = try #require(store.requestRefresh())
        #expect(!store.isLoadingInitial)
        #expect(!store.isLoadingOlder)
        #expect(store.isLoadingNewer)
        _ = store.resolve(newer, with: .success(success(page(ids: []))))
    }

    @MainActor
    private func page(
        ids: [String],
        hasNextPage: Bool = false
    ) -> ExploreTimelinePage<Edge> {
        ExploreTimelinePage(
            edges: ids.map { Edge(cursor: "cursor-\($0)", timelineListID: $0) },
            pageInfo: ExploreTimelinePageInfo(
                hasPreviousPage: false,
                hasNextPage: hasNextPage,
                startCursor: ids.first.map { "start-\($0)" },
                endCursor: ids.last.map { "end-\($0)" }
            )
        )
    }

    private func success(_ page: ExploreTimelinePage<Edge>) -> ExploreTimelineFetchResult<Edge> {
        ExploreTimelineFetchResult(page: page, errorMessage: nil)
    }

    private struct TestError: LocalizedError {
        var errorDescription: String? {
            "stale failure"
        }
    }
}

extension ExploreTimelineScopeStoreTests {
    @Test("SOC-8/POST-11: deleting a shared post fences its stale response and preserves queued refresh replay")
    @MainActor
    func postContentDeletionFencesStaleSharedPostCompletion() throws {
        let store = ExploreTimelineScopeStore<Edge>()
        let sharedRow = Edge(
            cursor: "cursor-share-row",
            timelineListID: "share-row",
            postID: "share-row",
            displayedPostID: "original-post"
        )
        let initialPage = ExploreTimelinePage(
            edges: [sharedRow],
            pageInfo: ExploreTimelinePageInfo(
                hasPreviousPage: false,
                hasNextPage: true,
                startCursor: "cursor-share-row",
                endCursor: "cursor-share-row"
            )
        )
        let initial = try #require(store.startInitialLoadIfNeeded())
        _ = store.resolve(initial, with: .success(success(initialPage)))
        let staleOlder = try #require(store.requestOlderPage())
        #expect(store.requestRefresh() == nil)

        let result = store.applyPostContentEvent(.postDeleted(postID: "original-post"))
        let replay = try #require(result.replay)

        #expect(result == .applied(replay: replay))
        #expect(!store.isCurrent(staleOlder))
        #expect(store.edges.isEmpty)
        #expect(replay.operation == .newer("cursor-share-row"))

        _ = store.resolve(staleOlder, with: .success(success(initialPage)))
        #expect(store.edges.isEmpty)

        _ = store.resolve(replay, with: .success(success(page(ids: []))))
        #expect(store.edges.isEmpty)
        #expect(!store.isLoading)
    }

    @Test("SOC-8/POST-11: matching deletion without queued refresh reports mutation without replay")
    @MainActor
    func postContentDeletionWithoutQueuedRefreshReportsAppliedMutation() {
        let store = ExploreTimelineScopeStore<Edge>()
        store.replaceInitial(
            with: ExploreTimelinePage(
                edges: [
                    Edge(
                        cursor: "cursor-share-row",
                        timelineListID: "share-row",
                        postID: "share-row",
                        displayedPostID: "original-post"
                    )
                ],
                pageInfo: ExploreTimelinePageInfo(
                    hasPreviousPage: false,
                    hasNextPage: true,
                    startCursor: "cursor-share-row",
                    endCursor: "cursor-share-row"
                )
            )
        )

        let result = store.applyPostContentEvent(.postDeleted(postID: "original-post"))

        #expect(result == .applied(replay: nil))
        #expect(store.edges.isEmpty)
        #expect(store.startCursor == "cursor-share-row")
        #expect(store.endCursor == "cursor-share-row")
        #expect(store.hasNextPage)
    }

    @Test("SOC-8/POST-11: reply and bookmark events leave Explore rows unchanged")
    @MainActor
    func nonDeletionPostContentEventsAreIgnored() {
        let store = ExploreTimelineScopeStore<Edge>()
        let initialPage = page(ids: ["post-1"])
        store.replaceInitial(with: initialPage)

        #expect(
            store.applyPostContentEvent(
                .replyCreated(parentPostID: "post-1", replyPostID: "reply-1")
            ) == .ignored
        )
        #expect(
            store.applyPostContentEvent(
                .bookmarkChanged(postID: "post-1", isBookmarked: false)
            ) == .ignored
        )
        #expect(store.edges == initialPage.edges)
    }
}
