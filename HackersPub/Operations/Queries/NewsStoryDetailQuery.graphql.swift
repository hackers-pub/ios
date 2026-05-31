// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI
@_spi(Execution) @_spi(Unsafe) import ApolloAPI

public extension HackersPub {
  struct NewsStoryDetailQuery: GraphQLQuery {
    public static let operationName: String = "NewsStoryDetailQuery"
    public static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"query NewsStoryDetailQuery($id: UUID!, $after: String, $first: Int = 20) { newsStory(id: $id) { __typename id uuid url title siteName description discussionCount firstSharedAt latestActivityAt image { __typename url alt width height } sourceBreakdown { __typename local remote bluesky } sharingPosts(first: $first, after: $after) { __typename edges { __typename cursor node { __typename ...ProfilePostFields } } pageInfo { __typename hasNextPage endCursor } } } }"#,
        fragments: [ProfilePostFields.self]
      ))

    public var id: UUID
    public var after: GraphQLNullable<String>
    public var first: GraphQLNullable<Int32>

    public init(
      id: UUID,
      after: GraphQLNullable<String>,
      first: GraphQLNullable<Int32> = 20
    ) {
      self.id = id
      self.after = after
      self.first = first
    }

    @_spi(Unsafe) public var __variables: Variables? { [
      "id": id,
      "after": after,
      "first": first
    ] }

    public struct Data: HackersPub.SelectionSet {
      @_spi(Unsafe) public let __data: DataDict
      @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

      @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Query }
      @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
        .field("newsStory", NewsStory?.self, arguments: ["id": .variable("id")]),
      ] }
      @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
        NewsStoryDetailQuery.Data.self
      ] }

      /// Look up a news story (a shared link) by its row UUID, for the discussion permalink `/news/{uuid}`.  Returns `null` for a malformed id, or for a link that is not a public news story: only links with a qualifying public share (`latestActivityAt` is not `null`) resolve, so a link seen only in followers-only or direct posts stays private.  A link hidden from the feed by an exclusion pattern (`excludedFromNews`) is still reachable here.
      public var newsStory: NewsStory? { __data["newsStory"] }

      /// NewsStory
      ///
      /// Parent Type: `PostLink`
      public struct NewsStory: HackersPub.SelectionSet {
        @_spi(Unsafe) public let __data: DataDict
        @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

        @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.PostLink }
        @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .field("id", HackersPub.ID.self),
          .field("uuid", HackersPub.UUID.self),
          .field("url", HackersPub.URL.self),
          .field("title", String?.self),
          .field("siteName", String?.self),
          .field("description", String?.self),
          .field("discussionCount", Int.self),
          .field("firstSharedAt", HackersPub.DateTime?.self),
          .field("latestActivityAt", HackersPub.DateTime?.self),
          .field("image", Image?.self),
          .field("sourceBreakdown", SourceBreakdown.self),
          .field("sharingPosts", SharingPosts.self, arguments: [
            "first": .variable("first"),
            "after": .variable("after")
          ]),
        ] }
        @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
          NewsStoryDetailQuery.Data.NewsStory.self
        ] }

        public var id: HackersPub.ID { __data["id"] }
        /// The link's row UUID.  Use this for the stable discussion permalink `/news/{uuid}`; the opaque Relay `id` is for `node(id:)` lookups.
        public var uuid: HackersPub.UUID { __data["uuid"] }
        public var url: HackersPub.URL { __data["url"] }
        public var title: String? { __data["title"] }
        public var siteName: String? { __data["siteName"] }
        public var description: String? { __data["description"] }
        /// Size of this link's federated discussion: its non-bot public sharing posts plus their direct public (`public`/`unlisted`) replies and quotes.  Use this as the count of posts to read in the discussion (the `/news/{uuid}` page); unlike `postCount` it includes the replies and quotes, not just the shares.  Counts direct children only (deeper nesting is not traversed) and is viewer-independent (public posts only).
        public var discussionCount: Int { __data["discussionCount"] }
        /// When this link was first shared publicly by a non-bot account, or `null` if it has never been.  Drives the `NEWEST` order.
        public var firstSharedAt: HackersPub.DateTime? { __data["firstSharedAt"] }
        /// Timestamp of the freshest activity on this link's qualifying shares (the share itself, a reply, a quote, or a reaction); shares are public and authored by non-bot accounts.  A rapid repeat share by the same account does not refresh this (only a first share, a sufficiently-gapped re-share, or genuine replies/quotes/reactions do), so re-posting cannot keep a link pinned at the top.  `null` means the link is not a news story (no qualifying public share); such links are excluded from the feed.
        public var latestActivityAt: HackersPub.DateTime? { __data["latestActivityAt"] }
        public var image: Image? { __data["image"] }
        /// Counts of this link's public shares by origin (local / remote / Bluesky bridge), excluding shares from bot (`Service`/`Application`) accounts.
        public var sourceBreakdown: SourceBreakdown { __data["sourceBreakdown"] }
        /// The posts that share this link, most recently published first, filtered to those visible to the viewer.  Shares authored by bot accounts (`Service`/`Application` actors) are excluded, matching the scoring.  These are the roots of the link's discussion tree.
        public var sharingPosts: SharingPosts { __data["sharingPosts"] }

        /// NewsStory.Image
        ///
        /// Parent Type: `PostLinkImage`
        public struct Image: HackersPub.SelectionSet {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.PostLinkImage }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("__typename", String.self),
            .field("url", HackersPub.URL.self),
            .field("alt", String?.self),
            .field("width", Int?.self),
            .field("height", Int?.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            NewsStoryDetailQuery.Data.NewsStory.Image.self
          ] }

          public var url: HackersPub.URL { __data["url"] }
          public var alt: String? { __data["alt"] }
          public var width: Int? { __data["width"] }
          public var height: Int? { __data["height"] }
        }

        /// NewsStory.SourceBreakdown
        ///
        /// Parent Type: `NewsSourceBreakdown`
        public struct SourceBreakdown: HackersPub.SelectionSet {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.NewsSourceBreakdown }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("__typename", String.self),
            .field("local", Int.self),
            .field("remote", Int.self),
            .field("bluesky", Int.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            NewsStoryDetailQuery.Data.NewsStory.SourceBreakdown.self
          ] }

          /// Public shares authored by local Hackers' Pub accounts.
          public var local: Int { __data["local"] }
          /// Public shares from generic remote fediverse instances (Mastodon, Pleroma, etc.).
          public var remote: Int { __data["remote"] }
          /// Public shares bridged from Bluesky (`@…@bsky.brid.gy`).
          public var bluesky: Int { __data["bluesky"] }
        }

        /// NewsStory.SharingPosts
        ///
        /// Parent Type: `PostLinkSharingPostsConnection`
        public struct SharingPosts: HackersPub.SelectionSet {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.PostLinkSharingPostsConnection }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("__typename", String.self),
            .field("edges", [Edge].self),
            .field("pageInfo", PageInfo.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            NewsStoryDetailQuery.Data.NewsStory.SharingPosts.self
          ] }

          public var edges: [Edge] { __data["edges"] }
          public var pageInfo: PageInfo { __data["pageInfo"] }

          /// NewsStory.SharingPosts.Edge
          ///
          /// Parent Type: `PostLinkSharingPostsConnectionEdge`
          public struct Edge: HackersPub.SelectionSet {
            @_spi(Unsafe) public let __data: DataDict
            @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

            @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.PostLinkSharingPostsConnectionEdge }
            @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
              .field("__typename", String.self),
              .field("cursor", String.self),
              .field("node", Node.self),
            ] }
            @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
              NewsStoryDetailQuery.Data.NewsStory.SharingPosts.Edge.self
            ] }

            public var cursor: String { __data["cursor"] }
            public var node: Node { __data["node"] }

            /// NewsStory.SharingPosts.Edge.Node
            ///
            /// Parent Type: `Post`
            public struct Node: HackersPub.SelectionSet {
              @_spi(Unsafe) public let __data: DataDict
              @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

              @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Interfaces.Post }
              @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
                .field("__typename", String.self),
                .fragment(ProfilePostFields.self),
              ] }
              @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                NewsStoryDetailQuery.Data.NewsStory.SharingPosts.Edge.Node.self,
                ProfilePostFields.self
              ] }

              public var id: HackersPub.ID { __data["id"] }
              /// The post's title. Non-null for `Article`s; `null` for `Note`s, boost wrappers, and `Question`s.
              public var name: String? { __data["name"] }
              public var published: HackersPub.DateTime { __data["published"] }
              /// Author-provided or LLM-generated summary of the post. `null` when no summary has been set. For LLM summaries, check `ArticleContent.summary` and `summaryStarted` instead, as those are tracked per language on articles.
              public var summary: String? { __data["summary"] }
              /// The post's full HTML content, with custom emoji shortcodes rendered as `<img>` elements and external links annotated with `target="_blank"`. Boost wrappers have empty content; use `sharedPost.content` instead.
              public var content: HackersPub.HTML { __data["content"] }
              /// Plain-text excerpt of the post. Returns `summary` when set; otherwise falls back to the HTML content stripped of tags. For a truncated HTML preview, use `excerptHtml` instead.
              public var excerpt: String { __data["excerpt"] }
              /// The canonical, human-readable URL of this post. For source-backed local posts the path encodes the local source identifier — `Note.sourceId` for notes, `Article.publishedYear` + `Article.slug` for articles — **not** `Post.uuid`. For federated remote posts and local share wrappers (boosts) this is whatever URL the originating instance advertised — copied from the shared post in the boost case — and is unrelated to the wrapper's own row PK. Prefer this field over hand-building a path from `Post.uuid`: `uuid` is the row PK and does not match the path here for source-backed local posts.
              public var url: HackersPub.URL? { __data["url"] }
              /// The post's ActivityPub IRI, used as its canonical identifier in federation. For local posts this is an `/ap/…` endpoint; for remote posts it is whatever IRI the originating instance assigned. Prefer `url` for human-readable links.
              public var iri: HackersPub.URL { __data["iri"] }
              /// Whether the authenticated viewer has boosted this post. Always `false` for unauthenticated requests.
              public var viewerHasShared: Bool { __data["viewerHasShared"] }
              /// Whether the authenticated viewer has bookmarked this post. Always `false` for unauthenticated requests.
              public var viewerHasBookmarked: Bool { __data["viewerHasBookmarked"] }
              /// The actor who authored or boosted this post.
              public var actor: Actor { __data["actor"] }
              /// Media attachments on this post, in display order. For federated posts the URLs point to the originating instance.
              public var media: [Medium] { __data["media"] }
              /// The post being boosted. Non-null only for boost wrapper rows. When this is non-null, `content` is empty and `url` mirrors the shared post's URL.
              public var sharedPost: SharedPost? { __data["sharedPost"] }
              /// The post being quoted inline. `null` for posts that are not quotes.
              public var quotedPost: QuotedPost? { __data["quotedPost"] }
              public var engagementStats: EngagementStats { __data["engagementStats"] }
              public var reactionGroups: [ReactionGroup] { __data["reactionGroups"] }
              /// Actors explicitly @-mentioned in this post. Does not include implicit mentions (e.g., the author of the post being replied to).
              public var mentions: Mentions { __data["mentions"] }

              public struct Fragments: FragmentContainer {
                @_spi(Unsafe) public let __data: DataDict
                @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

                public var profilePostFields: ProfilePostFields { _toFragment() }
              }

              public typealias Actor = ProfilePostFields.Actor

              public typealias Medium = ProfilePostFields.Medium

              public typealias SharedPost = ProfilePostFields.SharedPost

              public typealias QuotedPost = ProfilePostFields.QuotedPost

              public typealias EngagementStats = ProfilePostFields.EngagementStats

              public typealias ReactionGroup = ProfilePostFields.ReactionGroup

              public typealias Mentions = ProfilePostFields.Mentions
            }
          }

          /// NewsStory.SharingPosts.PageInfo
          ///
          /// Parent Type: `PageInfo`
          public struct PageInfo: HackersPub.SelectionSet {
            @_spi(Unsafe) public let __data: DataDict
            @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

            @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.PageInfo }
            @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
              .field("__typename", String.self),
              .field("hasNextPage", Bool.self),
              .field("endCursor", String?.self),
            ] }
            @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
              NewsStoryDetailQuery.Data.NewsStory.SharingPosts.PageInfo.self
            ] }

            public var hasNextPage: Bool { __data["hasNextPage"] }
            public var endCursor: String? { __data["endCursor"] }
          }
        }
      }
    }
  }

}