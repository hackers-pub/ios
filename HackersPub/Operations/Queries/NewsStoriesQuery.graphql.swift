// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI
@_spi(Execution) @_spi(Unsafe) import ApolloAPI

public extension HackersPub {
  struct NewsStoriesQuery: GraphQLQuery {
    public static let operationName: String = "NewsStoriesQuery"
    public static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"query NewsStoriesQuery($order: NewsOrder = POPULAR, $after: String, $first: Int = 25) { viewer { __typename id moderator } newsStories(order: $order, first: $first, after: $after) { __typename edges { __typename cursor node { __typename id uuid url title siteName description discussionCount latestActivityAt penalty image { __typename url alt width height } } } pageInfo { __typename hasNextPage endCursor } } }"#
      ))

    public var order: GraphQLNullable<GraphQLEnum<NewsOrder>>
    public var after: GraphQLNullable<String>
    public var first: GraphQLNullable<Int32>

    public init(
      order: GraphQLNullable<GraphQLEnum<NewsOrder>> = .init(.popular),
      after: GraphQLNullable<String>,
      first: GraphQLNullable<Int32> = 25
    ) {
      self.order = order
      self.after = after
      self.first = first
    }

    @_spi(Unsafe) public var __variables: Variables? { [
      "order": order,
      "after": after,
      "first": first
    ] }

    public struct Data: HackersPub.SelectionSet {
      @_spi(Unsafe) public let __data: DataDict
      @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

      @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Query }
      @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
        .field("viewer", Viewer?.self),
        .field("newsStories", NewsStories.self, arguments: [
          "order": .variable("order"),
          "first": .variable("first"),
          "after": .variable("after")
        ]),
      ] }
      @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
        NewsStoriesQuery.Data.self
      ] }

      /// The `Account` of the currently authenticated user, or `null` when not authenticated. Use this as the entry point for all viewer-specific data (notifications, drafts, settings).
      public var viewer: Viewer? { __data["viewer"] }
      /// Links shared across the fediverse, ranked as a news feed.  Forward pagination only (`first`/`after`); `last`/`before` raise a `PAGINATION_ERROR`.  Pages are capped at 100 stories.  No authentication required.
      public var newsStories: NewsStories { __data["newsStories"] }

      /// Viewer
      ///
      /// Parent Type: `Account`
      public struct Viewer: HackersPub.SelectionSet {
        @_spi(Unsafe) public let __data: DataDict
        @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

        @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Account }
        @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .field("id", HackersPub.ID.self),
          .field("moderator", Bool.self),
        ] }
        @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
          NewsStoriesQuery.Data.Viewer.self
        ] }

        public var id: HackersPub.ID { __data["id"] }
        /// Whether this account has moderator privileges. Moderators can view all accounts, see moderation-only fields such as `postCount` and `lastPostPublished`, and perform administrative mutations such as `deleteOrphanMedia` and `regenerateInvitations`.
        public var moderator: Bool { __data["moderator"] }
      }

      /// NewsStories
      ///
      /// Parent Type: `QueryNewsStoriesConnection`
      public struct NewsStories: HackersPub.SelectionSet {
        @_spi(Unsafe) public let __data: DataDict
        @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

        @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.QueryNewsStoriesConnection }
        @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .field("edges", [Edge].self),
          .field("pageInfo", PageInfo.self),
        ] }
        @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
          NewsStoriesQuery.Data.NewsStories.self
        ] }

        public var edges: [Edge] { __data["edges"] }
        public var pageInfo: PageInfo { __data["pageInfo"] }

        /// NewsStories.Edge
        ///
        /// Parent Type: `QueryNewsStoriesConnectionEdge`
        public struct Edge: HackersPub.SelectionSet {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.QueryNewsStoriesConnectionEdge }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("__typename", String.self),
            .field("cursor", String.self),
            .field("node", Node.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            NewsStoriesQuery.Data.NewsStories.Edge.self
          ] }

          public var cursor: String { __data["cursor"] }
          public var node: Node { __data["node"] }

          /// NewsStories.Edge.Node
          ///
          /// Parent Type: `PostLink`
          public struct Node: HackersPub.SelectionSet {
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
              .field("latestActivityAt", HackersPub.DateTime?.self),
              .field("penalty", GraphQLEnum<HackersPub.NewsPenalty>?.self),
              .field("image", Image?.self),
            ] }
            @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
              NewsStoriesQuery.Data.NewsStories.Edge.Node.self
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
            /// Timestamp of the freshest activity on this link's qualifying shares (the share itself, a reply, a quote, or a reaction); shares are public and authored by non-bot accounts.  A rapid repeat share by the same account does not refresh this (only a first share, a sufficiently-gapped re-share, or genuine replies/quotes/reactions do), so re-posting cannot keep a link pinned at the top.  `null` means the link is not a news story (no qualifying public share); such links are excluded from the feed.
            public var latestActivityAt: HackersPub.DateTime? { __data["latestActivityAt"] }
            /// The moderator score penalty on this link (demoting it in the `POPULAR` feed).  `null` for non-moderators; moderators see `NONE` when the link is unpenalized.  Set it with `setNewsScorePenalty`.
            public var penalty: GraphQLEnum<HackersPub.NewsPenalty>? { __data["penalty"] }
            public var image: Image? { __data["image"] }

            /// NewsStories.Edge.Node.Image
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
                NewsStoriesQuery.Data.NewsStories.Edge.Node.Image.self
              ] }

              public var url: HackersPub.URL { __data["url"] }
              public var alt: String? { __data["alt"] }
              public var width: Int? { __data["width"] }
              public var height: Int? { __data["height"] }
            }
          }
        }

        /// NewsStories.PageInfo
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
            NewsStoriesQuery.Data.NewsStories.PageInfo.self
          ] }

          public var hasNextPage: Bool { __data["hasNextPage"] }
          public var endCursor: String? { __data["endCursor"] }
        }
      }
    }
  }

}