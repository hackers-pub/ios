import Foundation

enum PostContentListHost: CaseIterable {
    case timeline
    case explore
    case search
    case actorProfile
    case bookmarks
    case newsSharingPosts
    case sharesSheet
}

struct PostListItemIdentity: Equatable {
    let rowID: String
    let postID: String
    let displayedPostID: String?

    func matchesDeletedPost(_ postID: String) -> Bool {
        self.postID == postID || displayedPostID == postID
    }
}

func postListItemIdentity<Post: PostProtocol>(rowID: String, post: Post) -> PostListItemIdentity {
    PostListItemIdentity(
        rowID: rowID,
        postID: post.id,
        displayedPostID: post.sharedPost?.id
    )
}

enum PostContentListEventAction: Equatable {
    case none
    case remove(rowIDs: [String])
}

enum PostContentListEventRouter {
    static func route(
        _ event: PostContentEvent,
        host: PostContentListHost,
        rows: [PostListItemIdentity],
        eventGeneration: Int,
        activeGeneration: Int
    ) -> PostContentListEventAction {
        _ = host
        guard eventGeneration == activeGeneration else { return .none }
        let postID: String
        switch event {
        case let .postDeleted(deletedPostID):
            postID = deletedPostID
        case let .bookmarkChanged(changedPostID, isBookmarked):
            guard host == .bookmarks, !isBookmarked else { return .none }
            postID = changedPostID
        case .replyCreated:
            return .none
        }

        let rowIDs = rows
            .filter { $0.matchesDeletedPost(postID) }
            .map(\.rowID)
        return rowIDs.isEmpty ? .none : .remove(rowIDs: rowIDs)
    }
}

enum PostBookmarkContentEventRouter {
    static func bookmarkedState(
        from event: PostContentEvent,
        targetPostID: String
    ) -> Bool? {
        guard case let .bookmarkChanged(postID, isBookmarked) = event,
              postID == targetPostID
        else {
            return nil
        }
        return isBookmarked
    }
}
