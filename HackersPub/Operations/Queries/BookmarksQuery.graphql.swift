// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI
@_spi(Execution) @_spi(Unsafe) import ApolloAPI

public extension HackersPub {
  struct BookmarksQuery: GraphQLQuery {
    public static let operationName: String = "BookmarksQuery"
    public static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"query BookmarksQuery($after: String, $before: String, $first: Int, $last: Int, $postType: PostType) { bookmarks( first: $first after: $after before: $before last: $last postType: $postType ) { __typename edges { __typename cursor node { __typename ...ProfilePostFields } } pageInfo { __typename hasPreviousPage hasNextPage startCursor endCursor } } }"#,
        fragments: [ProfilePostFields.self]
      ))

    public var after: GraphQLNullable<String>
    public var before: GraphQLNullable<String>
    public var first: GraphQLNullable<Int32>
    public var last: GraphQLNullable<Int32>
    public var postType: GraphQLNullable<GraphQLEnum<PostType>>

    public init(
      after: GraphQLNullable<String>,
      before: GraphQLNullable<String>,
      first: GraphQLNullable<Int32>,
      last: GraphQLNullable<Int32>,
      postType: GraphQLNullable<GraphQLEnum<PostType>>
    ) {
      self.after = after
      self.before = before
      self.first = first
      self.last = last
      self.postType = postType
    }

    @_spi(Unsafe) public var __variables: Variables? { [
      "after": after,
      "before": before,
      "first": first,
      "last": last,
      "postType": postType
    ] }

    public struct Data: HackersPub.SelectionSet {
      @_spi(Unsafe) public let __data: DataDict
      @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

      @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Query }
      @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
        .field("bookmarks", Bookmarks.self, arguments: [
          "first": .variable("first"),
          "after": .variable("after"),
          "before": .variable("before"),
          "last": .variable("last"),
          "postType": .variable("postType")
        ]),
      ] }
      @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
        BookmarksQuery.Data.self
      ] }

      /// The authenticated viewer's bookmarked posts, newest-bookmarked first. Throws `AUTHENTICATION_REQUIRED` when called without a session.
      public var bookmarks: Bookmarks { __data["bookmarks"] }

      /// Bookmarks
      ///
      /// Parent Type: `QueryBookmarksConnection`
      public struct Bookmarks: HackersPub.SelectionSet {
        @_spi(Unsafe) public let __data: DataDict
        @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

        @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.QueryBookmarksConnection }
        @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .field("edges", [Edge].self),
          .field("pageInfo", PageInfo.self),
        ] }
        @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
          BookmarksQuery.Data.Bookmarks.self
        ] }

        public var edges: [Edge] { __data["edges"] }
        public var pageInfo: PageInfo { __data["pageInfo"] }

        /// Bookmarks.Edge
        ///
        /// Parent Type: `QueryBookmarksConnectionEdge`
        public struct Edge: HackersPub.SelectionSet {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.QueryBookmarksConnectionEdge }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("__typename", String.self),
            .field("cursor", String.self),
            .field("node", Node.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            BookmarksQuery.Data.Bookmarks.Edge.self
          ] }

          public var cursor: String { __data["cursor"] }
          public var node: Node { __data["node"] }

          /// Bookmarks.Edge.Node
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
              BookmarksQuery.Data.Bookmarks.Edge.Node.self,
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

        /// Bookmarks.PageInfo
        ///
        /// Parent Type: `PageInfo`
        public struct PageInfo: HackersPub.SelectionSet {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.PageInfo }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("__typename", String.self),
            .field("hasPreviousPage", Bool.self),
            .field("hasNextPage", Bool.self),
            .field("startCursor", String?.self),
            .field("endCursor", String?.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            BookmarksQuery.Data.Bookmarks.PageInfo.self
          ] }

          public var hasPreviousPage: Bool { __data["hasPreviousPage"] }
          public var hasNextPage: Bool { __data["hasNextPage"] }
          public var startCursor: String? { __data["startCursor"] }
          public var endCursor: String? { __data["endCursor"] }
        }
      }
    }
  }

}