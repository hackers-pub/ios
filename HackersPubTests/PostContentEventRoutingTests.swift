@testable import HackersPub
import Testing

struct PostContentEventRoutingTests {
    @Test func deletedPostRoutingRemovesOnlyMatchingSemanticRowsAcrossActiveHosts() {
        let rows = [
            PostListItemIdentity(rowID: "wrapper", postID: "wrapper", displayedPostID: "original"),
            PostListItemIdentity(rowID: "original", postID: "original", displayedPostID: nil),
            PostListItemIdentity(rowID: "other", postID: "other", displayedPostID: nil)
        ]

        for host in PostContentListHost.allCases {
            #expect(
                PostContentListEventRouter.route(
                    .postDeleted(postID: "original"),
                    host: host,
                    rows: rows,
                    eventGeneration: 8,
                    activeGeneration: 8
                ) == .remove(rowIDs: ["wrapper", "original"])
            )
            #expect(
                PostContentListEventRouter.route(
                    .postDeleted(postID: "original"),
                    host: host,
                    rows: rows,
                    eventGeneration: 7,
                    activeGeneration: 8
                ) == .none
            )
        }
    }

    @Test func deletedPostRoutingIsIdempotentAndDoesNotTouchReplacementList() {
        let replacementRows = [
            PostListItemIdentity(rowID: "new", postID: "new", displayedPostID: nil)
        ]

        #expect(
            PostContentListEventRouter.route(
                .postDeleted(postID: "original"),
                host: .search,
                rows: replacementRows,
                eventGeneration: 4,
                activeGeneration: 4
            ) == .none
        )
        #expect(
            PostContentListEventRouter.route(
                .postDeleted(postID: "original"),
                host: .search,
                rows: [],
                eventGeneration: 4,
                activeGeneration: 4
            ) == .none
        )
    }

    @Test func guestShareLongPressHasTheSamePublicShareDestinationAsTap() {
        let tap = PostEngagementAccessPolicy.share(
            isAuthenticated: false,
            actionsSwapped: false,
            isAlternateAction: false,
            postID: "post"
        )
        let longPress = PostEngagementAccessPolicy.share(
            isAuthenticated: false,
            actionsSwapped: true,
            isAlternateAction: true,
            postID: "post"
        )

        #expect(tap == .viewShares(postID: "post"))
        #expect(longPress == tap)
    }
}
