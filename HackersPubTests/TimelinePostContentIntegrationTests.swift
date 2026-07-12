@testable import HackersPub
import Testing

struct TimelinePostContentIntegrationTests {
    @Test func sharedTimelinePostsExposeTypedNestedQuotes() {
        assertPostAndNestedQuoteConformance(
            HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge.Node.SharedPost.self
        )
        assertPostAndNestedQuoteConformance(
            HackersPub.PersonalTimelineQuery.Data.PersonalTimeline.Edge.Node.SharedPost.self
        )
        assertPostAndNestedQuoteConformance(
            HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge.Node.SharedPost.self
        )
    }

    @Test func deletingAnOriginalPostRemovesItsSharedRowsAcrossAllTimelineStatesWithoutResettingOlderPagination() {
        assertDeletedRowsPreserveOlderPagination(rows: deletedRows(for: PublicTimelineFeed.self))
        assertDeletedRowsPreserveOlderPagination(rows: deletedRows(for: PersonalTimelineFeed.self))
        assertDeletedRowsPreserveOlderPagination(rows: deletedRows(for: LocalTimelineFeed.self))
    }

    private func deletedRows<Feed>(for _: Feed.Type) -> [TimelinePostContentFixture<Feed>] {
        [
            TimelinePostContentFixture(
                rowID: "share-original",
                postID: "share",
                displayedPostID: "original"
            ),
            TimelinePostContentFixture(
                rowID: "original",
                postID: "original",
                displayedPostID: nil
            ),
            TimelinePostContentFixture(
                rowID: "retained",
                postID: "retained",
                displayedPostID: nil
            )
        ]
    }

    private func assertDeletedRowsPreserveOlderPagination<Feed>(
        rows: [TimelinePostContentFixture<Feed>]
    ) {
        var state = TimelineState<TimelinePostContentFixture<Feed>>()
        let initialRequest = state.beginInitial()
        #expect(initialRequest != nil)
        guard let initialRequest else { return }

        _ = state.replaceFirstPage(
            rows,
            pageInfo: TimelinePageInfo(
                hasPreviousPage: false,
                hasNextPage: true,
                startCursor: "share-cursor",
                endCursor: "retained-cursor"
            ),
            identifier: \.rowID,
            for: initialRequest
        )
        _ = state.finish(initialRequest, outcome: .success)

        applyTimelinePostContentEvent(.postDeleted(postID: "original"), to: &state) {
            PostListItemIdentity(
                rowID: $0.rowID,
                postID: $0.postID,
                displayedPostID: $0.displayedPostID
            )
        }

        #expect(state.edges.map(\.rowID) == ["retained"])
        #expect(state.hasNextPage)
        #expect(state.endCursor == "retained-cursor")
        #expect(state.beginMore() != nil)
    }

    private func assertPostAndNestedQuoteConformance<Post: PostProtocol>(_: Post.Type) {
        assertQuotedPostConformance(Post.QuotedPostType.self)
    }

    private func assertQuotedPostConformance(_: (some QuotedPostProtocol).Type) {}
}

private struct TimelinePostContentFixture<Feed>: Equatable {
    let rowID: String
    let postID: String
    let displayedPostID: String?
}

private enum PublicTimelineFeed {}
private enum PersonalTimelineFeed {}
private enum LocalTimelineFeed {}
