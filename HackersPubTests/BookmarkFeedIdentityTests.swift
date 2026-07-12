@testable import HackersPub
import Testing

struct BookmarkFeedIdentityTests {
    private struct BookmarkItem: Equatable {
        let postID: String
        let cursor: String
    }

    @Test("SOC-20: cursor changes cannot create a second row for the same post")
    func removesExistingAndRepeatedPostIDs() {
        let existingPost = BookmarkItem(postID: "post-1", cursor: "new-cursor-1")
        let firstNewPost = BookmarkItem(postID: "post-2", cursor: "cursor-2")
        let repeatedNewPost = BookmarkItem(postID: "post-2", cursor: "new-cursor-2")
        let incoming = [existingPost, firstNewPost, repeatedNewPost]

        let result = BookmarkFeedIdentity.itemsExcludingKnownIDs(
            incoming,
            knownIDs: ["post-1"],
            id: \.postID
        )

        #expect(result == [firstNewPost])
    }

    @Test("SOC-20: newly accepted bookmark rows retain server order")
    func preservesIncomingOrderForUniquePostIDs() {
        let firstPost = BookmarkItem(postID: "post-3", cursor: "cursor-3")
        let secondPost = BookmarkItem(postID: "post-2", cursor: "cursor-2")
        let incoming = [firstPost, secondPost]

        let result = BookmarkFeedIdentity.itemsExcludingKnownIDs(
            incoming,
            knownIDs: [],
            id: \.postID
        )

        #expect(result == incoming)
    }

    @Test("SOC-20: duplicate first-page cursors cannot change the unique pagination trigger")
    func normalizesInitialPageBeforeComputingPaginationTrigger() {
        let firstPost = BookmarkItem(postID: "post-1", cursor: "cursor-1")
        let lastUniquePost = BookmarkItem(postID: "post-2", cursor: "cursor-2")
        let duplicateLastEdge = BookmarkItem(postID: "post-1", cursor: "cursor-3")

        let normalized = BookmarkFeedIdentity.normalizedPage(
            [firstPost, lastUniquePost, duplicateLastEdge],
            id: \.postID
        )

        #expect(normalized.items == [firstPost, lastUniquePost])
        #expect(normalized.paginationTriggerID == "post-2")
    }
}
