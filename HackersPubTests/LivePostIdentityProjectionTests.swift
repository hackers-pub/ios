@_spi(Unsafe) import ApolloAPI
@testable import HackersPub
import Testing

private typealias PublicTimelineEdge = HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge
private typealias PublicTimelineNode = PublicTimelineEdge.Node
private typealias LocalTimelineEdge = HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge
private typealias LocalTimelineNode = LocalTimelineEdge.Node
private typealias PersonalTimelineNode = HackersPub.PersonalTimelineQuery.Data.PersonalTimeline.Edge.Node
private typealias BookmarkNode = HackersPub.BookmarksQuery.Data.Bookmarks.Edge.Node
private typealias ProfilePostsNode = HackersPub.ActorByHandleQuery.Data.ActorByHandle.Posts.Edge.Node
private typealias ProfileNotesNode = HackersPub.ActorNotesQuery.Data.ActorByHandle.Notes.Edge.Node
private typealias ProfileArticlesNode = HackersPub.ActorArticlesQuery.Data.ActorByHandle.Articles.Edge.Node
private typealias SearchNode = HackersPub.SearchPostQuery.Data.SearchPost.Edge.Node
private typealias NewsNode = HackersPub.NewsStoryDetailQuery.Data.NewsStory.SharingPosts.Edge.Node

struct LivePostIdentityProjectionTests {
    @Test("[POST-11] timeline post sources retain wrapper and displayed shared-post identities")
    func timelinePostSourcesProjectLiveSharedPostIdentity() {
        let publicPost = sharedPost(
            PublicTimelineNode.self,
            wrapperID: "public-wrapper",
            sharedPostID: "public-original"
        )
        let localPost = sharedPost(
            LocalTimelineNode.self,
            wrapperID: "local-wrapper",
            sharedPostID: "local-original"
        )
        let personalPost = sharedPost(
            PersonalTimelineNode.self,
            wrapperID: "personal-wrapper",
            sharedPostID: "personal-original"
        )

        assertProjection(
            postListItemIdentity(rowID: "public-wrapper", post: publicPost),
            host: .timeline,
            rowID: "public-wrapper",
            wrapperID: "public-wrapper",
            sharedPostID: "public-original"
        )
        assertProjection(
            postListItemIdentity(rowID: "local-wrapper", post: localPost),
            host: .timeline,
            rowID: "local-wrapper",
            wrapperID: "local-wrapper",
            sharedPostID: "local-original"
        )
        assertProjection(
            postListItemIdentity(rowID: "personal-wrapper", post: personalPost),
            host: .timeline,
            rowID: "personal-wrapper",
            wrapperID: "personal-wrapper",
            sharedPostID: "personal-original"
        )
    }

    @Test("[POST-11] local and global Explore edges project generated shared-post identities")
    func exploreEdgesProjectLiveSharedPostIdentity() {
        let localEdge = exploreEdge(
            LocalTimelineEdge.self,
            node: sharedPostData(
                LocalTimelineNode.self,
                wrapperID: "explore-local-wrapper",
                sharedPostID: "explore-local-original"
            )
        )
        let globalEdge = exploreEdge(
            PublicTimelineEdge.self,
            node: sharedPostData(
                PublicTimelineNode.self,
                wrapperID: "explore-global-wrapper",
                sharedPostID: "explore-global-original"
            )
        )

        assertProjection(
            localEdge.postContentListIdentity,
            host: .explore,
            rowID: "explore-local-wrapper",
            wrapperID: "explore-local-wrapper",
            sharedPostID: "explore-local-original"
        )
        assertProjection(
            globalEdge.postContentListIdentity,
            host: .explore,
            rowID: "explore-global-wrapper",
            wrapperID: "explore-global-wrapper",
            sharedPostID: "explore-global-original"
        )
    }

    @Test("[POST-11] bookmark and news post sources retain shared-post identities")
    func bookmarkAndNewsPostSourcesProjectLiveSharedPostIdentity() {
        let bookmark = sharedPost(
            BookmarkNode.self,
            wrapperID: "bookmark-wrapper",
            sharedPostID: "bookmark-original"
        )
        let news = sharedPost(
            NewsNode.self,
            wrapperID: "news-wrapper",
            sharedPostID: "news-original"
        )

        assertProjection(
            postListItemIdentity(rowID: bookmark.id, post: bookmark),
            host: .bookmarks,
            rowID: "bookmark-wrapper",
            wrapperID: "bookmark-wrapper",
            sharedPostID: "bookmark-original"
        )
        assertProjection(
            postListItemIdentity(rowID: news.id, post: news),
            host: .newsSharingPosts,
            rowID: "news-wrapper",
            wrapperID: "news-wrapper",
            sharedPostID: "news-original"
        )
    }

    @Test("[POST-11] profile post sources retain shared-post identities")
    func profilePostSourcesProjectLiveSharedPostIdentity() {
        let profilePost = sharedPost(
            ProfilePostsNode.self,
            wrapperID: "profile-post-wrapper",
            sharedPostID: "profile-post-original"
        )
        let profileNote = sharedPost(
            ProfileNotesNode.self,
            wrapperID: "profile-note-wrapper",
            sharedPostID: "profile-note-original"
        )
        let profileArticle = sharedPost(
            ProfileArticlesNode.self,
            wrapperID: "profile-article-wrapper",
            sharedPostID: "profile-article-original"
        )

        assertProjection(
            postListItemIdentity(rowID: profilePost.id, post: profilePost),
            host: .actorProfile,
            rowID: "profile-post-wrapper",
            wrapperID: "profile-post-wrapper",
            sharedPostID: "profile-post-original"
        )
        assertProjection(
            postListItemIdentity(rowID: profileNote.id, post: profileNote),
            host: .actorProfile,
            rowID: "profile-note-wrapper",
            wrapperID: "profile-note-wrapper",
            sharedPostID: "profile-note-original"
        )
        assertProjection(
            postListItemIdentity(rowID: profileArticle.id, post: profileArticle),
            host: .actorProfile,
            rowID: "profile-article-wrapper",
            wrapperID: "profile-article-wrapper",
            sharedPostID: "profile-article-original"
        )
    }

    @Test("[POST-11] search post adapter retains its row and displayed shared-post identity")
    func searchPostAdapterProjectsLiveSharedPostIdentity() throws {
        let post = sharedPost(
            SearchNode.self,
            wrapperID: "search-wrapper",
            sharedPostID: "search-original"
        )
        let identity = try #require(SearchResultType.post(post).postContentListIdentity)

        assertProjection(
            identity,
            host: .search,
            rowID: "post-search-wrapper",
            wrapperID: "search-wrapper",
            sharedPostID: "search-original"
        )
    }

    private func assertProjection(
        _ identity: PostListItemIdentity,
        host: PostContentListHost,
        rowID: String,
        wrapperID: String,
        sharedPostID: String
    ) {
        #expect(identity.rowID == rowID)
        #expect(identity.postID == wrapperID)
        #expect(identity.displayedPostID == sharedPostID)
        #expect(
            PostContentListEventRouter.route(
                .postDeleted(postID: wrapperID),
                host: host,
                rows: [identity],
                eventGeneration: 0,
                activeGeneration: 0
            ) == .remove(rowIDs: [rowID])
        )
        #expect(
            PostContentListEventRouter.route(
                .postDeleted(postID: sharedPostID),
                host: host,
                rows: [identity],
                eventGeneration: 0,
                activeGeneration: 0
            ) == .remove(rowIDs: [rowID])
        )
    }

    private func sharedPost<Node: SelectionSet>(
        _ node: Node.Type,
        wrapperID: String,
        sharedPostID: String
    ) -> Node {
        Node(_dataDict: sharedPostData(node, wrapperID: wrapperID, sharedPostID: sharedPostID))
    }

    private func sharedPostData<Node: SelectionSet>(
        _ node: Node.Type,
        wrapperID: String,
        sharedPostID: String
    ) -> DataDict {
        var sharedPost: [String: DataDict.FieldValue] = [:]
        sharedPost["__typename"] = "Note"
        sharedPost["id"] = sharedPostID

        var data: [String: DataDict.FieldValue] = [:]
        data["__typename"] = "Note"
        data["id"] = wrapperID
        data["sharedPost"] = DataDict(data: sharedPost, fulfilledFragments: [])
        return DataDict(data: data, fulfilledFragments: [ObjectIdentifier(node)])
    }

    private func exploreEdge<Edge: SelectionSet>(
        _ edge: Edge.Type,
        node: DataDict
    ) -> Edge {
        var data: [String: DataDict.FieldValue] = [:]
        data["__typename"] = "QueryPublicTimelineConnectionEdge"
        data["cursor"] = "explore-cursor"
        data["node"] = node
        return Edge(_dataDict: DataDict(data: data, fulfilledFragments: [ObjectIdentifier(edge)]))
    }
}
