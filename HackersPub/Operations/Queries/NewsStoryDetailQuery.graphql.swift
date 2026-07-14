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

      /// Look up a news story (a shared link) by its row UUID, for the discussion permalink `/news/{uuid}`.  Returns `null` for a malformed id, or for a link that is not a public news story: only links with a qualifying public share (`latestActivity` is not `null`) resolve, so a link seen only in followers-only or direct posts stays private.  A link hidden from the feed by an exclusion pattern (`excludedFromNews`) is still reachable here.
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
        /// Size of this link's federated discussion: its qualifying public direct linked sharing posts (non-bot accounts, or curated preferred sharers) plus their direct public (`public`/`unlisted`) replies and quotes.  Use this as the count of posts to read in the discussion (the `/news/{uuid}` page); unlike `postCount` it includes replies and quotes, but it does not include `Article` boosts that count only toward the score.  Counts direct children only (deeper nesting is not traversed) and is viewer-independent (public posts only).  Censored posts and posts by sanction-hidden actors are excluded, both as shares and as replies/quotes.
        public var discussionCount: Int { __data["discussionCount"] }
        /// Deprecated compatibility alias for `firstShared`. Use `firstShared` for the first qualifying public share timestamp.
        @available(*, deprecated, message: "Use `firstShared` instead.")
        public var firstSharedAt: HackersPub.DateTime? { __data["firstSharedAt"] }
        /// Deprecated compatibility alias for `latestActivity`. Use `latestActivity` for the freshest qualifying activity timestamp.
        @available(*, deprecated, message: "Use `latestActivity` instead.")
        public var latestActivityAt: HackersPub.DateTime? { __data["latestActivityAt"] }
        public var image: Image? { __data["image"] }
        /// Counts of this link's moderation-visible public shares by origin (local / remote / Bluesky bridge), including direct linked posts and boosts of `Article` posts backed by this link.  Excludes shares from bot (`Service`/`Application`) accounts that are not curated preferred sharers.
        public var sourceBreakdown: SourceBreakdown { __data["sourceBreakdown"] }
        /// The posts that share this link, most recently published first, limited to public or unlisted posts that are visible to the viewer.  Shares authored by bot accounts (`Service`/`Application` actors) are excluded unless the account is a curated preferred sharer.  These are the direct linked roots of the link's discussion tree; `Article` boosts can also affect `score`/`postCount` but are not returned here as roots.
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
              /// The post's title. Non-null for `Article`s and local poll `Question`s; `null` for `Note`s and boost wrappers.  `null` when the post is censored or its author is hidden by a moderation sanction (or it is a boost wrapper of such a post, whose title it copies) and the viewer is neither the content's author nor a moderator.
              public var name: String? { __data["name"] }
              public var published: HackersPub.DateTime { __data["published"] }
              /// Author-provided or LLM-generated summary of the post. `null` when no summary has been set. For LLM summaries, check `ArticleContent.summary` and `summaryStarted` instead, as those are tracked per language on articles.  `null` when the post is censored or its author is hidden by a moderation sanction (or it boosts such a post), and the viewer is neither the content's author nor a moderator.
              public var summary: String? { __data["summary"] }
              /// The post's full HTML content, with custom emoji shortcodes rendered as `<img>` elements and external links annotated with `target="_blank"`. Boost wrappers copy the boosted post's content; prefer `sharedPost.content`.  Empty when the post is censored or its author is hidden by a moderation sanction (or it boosts such a post), and the viewer is neither the content's author nor a moderator.
              public var content: HackersPub.HTML { __data["content"] }
              /// Plain-text excerpt of the post. Returns `summary` when set; otherwise falls back to the HTML content stripped of tags. For a truncated HTML preview, use `excerptHtml` instead.  Empty when the post is censored or its author is hidden by a moderation sanction (or it boosts such a post) and the viewer is neither the content's author nor a moderator.
              public var excerpt: String { __data["excerpt"] }
              /// The canonical, human-readable URL of this post. For source-backed local posts the path encodes the local source identifier: `Note.sourceId` for notes, `Article.publishedYear` + `Article.slug` for articles, and `Question.sourceId` for questions. It does not encode `Post.uuid`. For federated remote posts and local share wrappers (boosts) this is whatever URL the originating instance advertised (copied from the shared post in the boost case) and is unrelated to the wrapper's own row PK. Prefer this field over hand-building a path from `Post.uuid`: `uuid` is the row PK and does not match the path here for source-backed local posts.  `null` when the post is censored or its author is hidden by a moderation sanction, and the viewer is neither the content's author nor a moderator, EXCEPT for a local post (whose own permalink renders the notice): a boost wrapper's URL mirrors the boosted post's, and a remote post's URL points at the uncensored copy on its origin instance, so both are hidden.
              public var url: HackersPub.URL? { __data["url"] }
              /// The post's ActivityPub IRI, used as its canonical identifier in federation. For local posts this is an `/ap/…` endpoint; for remote posts it is whatever IRI the originating instance assigned. Prefer `url` for human-readable links.  When the post is censored or its author is hidden by a moderation sanction, and the viewer is neither the author nor a moderator, a remote IRI (or a boost wrapper's, whose `url` is also nulled) is replaced with the local permalink that renders the notice, so a `url ?? iri` fallback never leaks the uncensored origin. A local non-wrapper post keeps its own `/ap/…` IRI (it does not point outside this instance).
              public var iri: HackersPub.URL { __data["iri"] }
              /// Whether the selected viewer account has boosted this post. Always `false` for unauthenticated requests. Pass `actingAccountId` for an organization perspective.
              public var viewerHasShared: Bool { __data["viewerHasShared"] }
              /// Whether the authenticated viewer has bookmarked this post. Always `false` for unauthenticated requests.
              public var viewerHasBookmarked: Bool { __data["viewerHasBookmarked"] }
              /// The actor who authored or boosted this post.
              public var actor: Actor { __data["actor"] }
              /// Media attachments on this post, in display order. For federated posts the URLs point to the originating instance.  Empty when the post is censored or its author is hidden by a moderation sanction, and the viewer is neither the author nor a moderator: attachments are part of the hidden content.
              public var media: [Medium] { __data["media"] }
              /// The post being boosted. Non-null only for boost wrapper rows. When this is non-null, `content` is empty and `url` mirrors the shared post's URL.  `null` when the boost wrapper itself is censored, or its author is hidden by a moderation sanction, and the viewer is neither the author nor a moderator (what was boosted is the censored content), and also when the boosted post is not visible to the viewer (e.g., a followers-only post the viewer does not follow), so a boost cannot leak its private target.
              public var sharedPost: SharedPost? { __data["sharedPost"] }
              /// The post being quoted inline. `null` for posts that are not quotes, when the quoting post is censored or its author is hidden by a moderation sanction and the viewer is neither its author nor a moderator (the quoted target is part of the censored content), and also when the quoted post is not visible to the viewer (e.g., a followers-only post the viewer does not follow), so a public quote cannot leak its private target.
              public var quotedPost: QuotedPost? { __data["quotedPost"] }
              public var engagementStats: EngagementStats { __data["engagementStats"] }
              public var reactionGroups: [ReactionGroup] { __data["reactionGroups"] }
              /// Actors explicitly @-mentioned in this post. Does not include implicit mentions (e.g., the author of the post being replied to). Empty when the post is censored or its author is hidden by a moderation sanction, and the viewer is neither the author nor a moderator, since the mention targets are part of the censored content.
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