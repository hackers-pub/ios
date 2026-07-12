@testable import HackersPub
import Testing

@Suite(.serialized)
@MainActor
struct PostDetailEngagementLifecycleTests {
    @Test func detailSharesStateLoadsPagesInOrderAndStopsAtTheEnd() async {
        let loader = ControlledEngagementPageLoader<ShareActorInfo>()
        let state = PostDetailView.makeSharesState { cursor in
            await loader.load(after: cursor)
        }

        let initial = Task { await state.reload() }
        await loader.waitForRequests(1)
        loader.complete(
            request: 0,
            with: .success(detailSharePage(["alice", "alice", "bob"], hasMore: true, endCursor: "cursor-1"))
        )
        await initial.value

        let failedMore = Task { await state.loadMore() }
        await loader.waitForRequests(2)
        loader.complete(request: 1, with: .failure(.transport("offline")))
        await failedMore.value

        #expect(state.items.map(\.id) == ["alice", "bob"])
        #expect(state.cursor == "cursor-1")
        #expect(state.hasMore)
        #expect(state.paginationErrorMessage == "offline")

        let retry = Task { await state.retryLoadMore() }
        await loader.waitForRequests(3)
        loader.complete(
            request: 2,
            with: .success(detailSharePage(["bob", "carol"], hasMore: false, endCursor: nil))
        )
        await retry.value

        await state.loadMore()

        #expect(state.items.map(\.id) == ["alice", "bob", "carol"])
        #expect(loader.requestedCursors == [nil, "cursor-1", "cursor-1"])
        #expect(state.cursor == nil)
        #expect(!state.hasMore)
        #expect(state.initialErrorMessage == nil)
        #expect(state.paginationErrorMessage == nil)
    }

    @Test func detailSharesStateIgnoresCancelledStaleGeneration() async {
        let loader = ControlledEngagementPageLoader<ShareActorInfo>()
        let state = PostDetailView.makeSharesState { cursor in
            await loader.load(after: cursor)
        }

        let staleInitial = Task { await state.reload() }
        await loader.waitForRequests(1)
        state.cancelPendingLoads()
        await loader.waitForCancellations(1)

        let freshInitial = Task { await state.reload() }
        await loader.waitForRequests(2)
        loader.complete(
            request: 1,
            with: .success(detailSharePage(["fresh"], hasMore: true, endCursor: "fresh-cursor"))
        )
        await freshInitial.value

        loader.complete(
            request: 0,
            with: .success(detailSharePage(["stale"], hasMore: false, endCursor: nil))
        )
        await staleInitial.value

        #expect(state.items.map(\.id) == ["fresh"])
        #expect(state.cursor == "fresh-cursor")
        #expect(state.hasMore)
        #expect(!state.isLoadingInitial)
        #expect(loader.cancelledCursors == [nil])
    }

    @Test func guestDetailEngagementRoutesRemainReadOnlyAndCanReadReplies() {
        let postID = "shared-original"

        #expect(
            PostEngagementAccessPolicy.reply(
                isAuthenticated: false,
                postID: postID
            ) == .viewReplies(postID: postID)
        )
        #expect(
            PostEngagementAccessPolicy.share(
                isAuthenticated: false,
                actionsSwapped: false,
                isAlternateAction: false,
                postID: postID
            ) == .viewShares(postID: postID)
        )
        #expect(
            PostDetailReplyReadPolicy.action(
                hasPost: true,
                loadedReplyCount: 1,
                totalReplyCount: 1,
                hasRefreshFailure: false
            ) == .scroll
        )
    }

    private func detailSharePage(
        _ ids: [String],
        hasMore: Bool,
        endCursor: String?
    ) -> EngagementListPage<ShareActorInfo> {
        EngagementListPage(
            items: ids.map {
                ShareActorInfo(
                    id: $0,
                    name: nil,
                    handle: "\($0)@example.com",
                    avatarUrl: ""
                )
            },
            hasMore: hasMore,
            endCursor: endCursor
        )
    }
}
