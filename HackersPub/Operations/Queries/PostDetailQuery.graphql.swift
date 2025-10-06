// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI
@_spi(Execution) @_spi(Unsafe) import ApolloAPI

public extension HackersPub {
  struct PostDetailQuery: GraphQLQuery {
    public static let operationName: String = "PostDetailQuery"
    public static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"query PostDetailQuery($id: ID!, $repliesAfter: String) { node(id: $id) { __typename ... on Post { __typename id name published summary content url visibility actor { __typename id name handle avatarUrl } media { __typename url thumbnailUrl alt height width } sharedPost { __typename id name published summary content url actor { __typename id name handle avatarUrl } media { __typename url thumbnailUrl alt height width } engagementStats { __typename replies reactions shares quotes } } engagementStats { __typename replies reactions shares quotes } reactionGroups { __typename ... on EmojiReactionGroup { emoji reactors(first: 20) { __typename edges { __typename node { __typename id name handle avatarUrl } } pageInfo { __typename hasNextPage endCursor } totalCount } } ... on CustomEmojiReactionGroup { customEmoji { __typename id name imageUrl } reactors(first: 20) { __typename edges { __typename node { __typename id name handle avatarUrl } } pageInfo { __typename hasNextPage endCursor } totalCount } } } replies(first: 20, after: $repliesAfter) { __typename edges { __typename cursor node { __typename id name published summary content url actor { __typename id name handle avatarUrl } media { __typename url thumbnailUrl alt height width } sharedPost { __typename id name published summary content url actor { __typename id name handle avatarUrl } media { __typename url thumbnailUrl alt height width } engagementStats { __typename replies reactions shares quotes } } engagementStats { __typename replies reactions shares quotes } } } pageInfo { __typename hasNextPage endCursor } } } } }"#
      ))

    public var id: ID
    public var repliesAfter: GraphQLNullable<String>

    public init(
      id: ID,
      repliesAfter: GraphQLNullable<String>
    ) {
      self.id = id
      self.repliesAfter = repliesAfter
    }

    @_spi(Unsafe) public var __variables: Variables? { [
      "id": id,
      "repliesAfter": repliesAfter
    ] }

    public struct Data: HackersPub.SelectionSet {
      @_spi(Unsafe) public let __data: DataDict
      @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

      @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Query }
      @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
        .field("node", Node?.self, arguments: ["id": .variable("id")]),
      ] }
      @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
        PostDetailQuery.Data.self
      ] }

      public var node: Node? { __data["node"] }

      /// Node
      ///
      /// Parent Type: `Node`
      public struct Node: HackersPub.SelectionSet {
        @_spi(Unsafe) public let __data: DataDict
        @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

        @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Interfaces.Node }
        @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .inlineFragment(AsPost.self),
        ] }
        @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
          PostDetailQuery.Data.Node.self
        ] }

        public var asPost: AsPost? { _asInlineFragment() }

        /// Node.AsPost
        ///
        /// Parent Type: `Post`
        public struct AsPost: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = PostDetailQuery.Data.Node
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Interfaces.Post }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("id", HackersPub.ID.self),
            .field("name", String?.self),
            .field("published", HackersPub.DateTime.self),
            .field("summary", String?.self),
            .field("content", HackersPub.HTML.self),
            .field("url", HackersPub.URL?.self),
            .field("visibility", GraphQLEnum<HackersPub.PostVisibility>.self),
            .field("actor", Actor.self),
            .field("media", [Medium].self),
            .field("sharedPost", SharedPost?.self),
            .field("engagementStats", EngagementStats.self),
            .field("reactionGroups", [ReactionGroup].self),
            .field("replies", Replies.self, arguments: [
              "first": 20,
              "after": .variable("repliesAfter")
            ]),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            PostDetailQuery.Data.Node.self,
            PostDetailQuery.Data.Node.AsPost.self
          ] }

          public var id: HackersPub.ID { __data["id"] }
          public var name: String? { __data["name"] }
          public var published: HackersPub.DateTime { __data["published"] }
          public var summary: String? { __data["summary"] }
          public var content: HackersPub.HTML { __data["content"] }
          public var url: HackersPub.URL? { __data["url"] }
          public var visibility: GraphQLEnum<HackersPub.PostVisibility> { __data["visibility"] }
          public var actor: Actor { __data["actor"] }
          public var media: [Medium] { __data["media"] }
          public var sharedPost: SharedPost? { __data["sharedPost"] }
          public var engagementStats: EngagementStats { __data["engagementStats"] }
          public var reactionGroups: [ReactionGroup] { __data["reactionGroups"] }
          public var replies: Replies { __data["replies"] }

          /// Node.AsPost.Actor
          ///
          /// Parent Type: `Actor`
          public struct Actor: HackersPub.SelectionSet {
            @_spi(Unsafe) public let __data: DataDict
            @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

            @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Actor }
            @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
              .field("__typename", String.self),
              .field("id", HackersPub.ID.self),
              .field("name", HackersPub.HTML?.self),
              .field("handle", String.self),
              .field("avatarUrl", HackersPub.URL.self),
            ] }
            @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
              PostDetailQuery.Data.Node.AsPost.Actor.self
            ] }

            public var id: HackersPub.ID { __data["id"] }
            public var name: HackersPub.HTML? { __data["name"] }
            public var handle: String { __data["handle"] }
            public var avatarUrl: HackersPub.URL { __data["avatarUrl"] }
          }

          /// Node.AsPost.Medium
          ///
          /// Parent Type: `PostMedium`
          public struct Medium: HackersPub.SelectionSet {
            @_spi(Unsafe) public let __data: DataDict
            @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

            @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.PostMedium }
            @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
              .field("__typename", String.self),
              .field("url", HackersPub.URL.self),
              .field("thumbnailUrl", String?.self),
              .field("alt", String?.self),
              .field("height", Int?.self),
              .field("width", Int?.self),
            ] }
            @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
              PostDetailQuery.Data.Node.AsPost.Medium.self
            ] }

            public var url: HackersPub.URL { __data["url"] }
            public var thumbnailUrl: String? { __data["thumbnailUrl"] }
            public var alt: String? { __data["alt"] }
            public var height: Int? { __data["height"] }
            public var width: Int? { __data["width"] }
          }

          /// Node.AsPost.SharedPost
          ///
          /// Parent Type: `Post`
          public struct SharedPost: HackersPub.SelectionSet {
            @_spi(Unsafe) public let __data: DataDict
            @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

            @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Interfaces.Post }
            @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
              .field("__typename", String.self),
              .field("id", HackersPub.ID.self),
              .field("name", String?.self),
              .field("published", HackersPub.DateTime.self),
              .field("summary", String?.self),
              .field("content", HackersPub.HTML.self),
              .field("url", HackersPub.URL?.self),
              .field("actor", Actor.self),
              .field("media", [Medium].self),
              .field("engagementStats", EngagementStats.self),
            ] }
            @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
              PostDetailQuery.Data.Node.AsPost.SharedPost.self
            ] }

            public var id: HackersPub.ID { __data["id"] }
            public var name: String? { __data["name"] }
            public var published: HackersPub.DateTime { __data["published"] }
            public var summary: String? { __data["summary"] }
            public var content: HackersPub.HTML { __data["content"] }
            public var url: HackersPub.URL? { __data["url"] }
            public var actor: Actor { __data["actor"] }
            public var media: [Medium] { __data["media"] }
            public var engagementStats: EngagementStats { __data["engagementStats"] }

            /// Node.AsPost.SharedPost.Actor
            ///
            /// Parent Type: `Actor`
            public struct Actor: HackersPub.SelectionSet {
              @_spi(Unsafe) public let __data: DataDict
              @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

              @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Actor }
              @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
                .field("__typename", String.self),
                .field("id", HackersPub.ID.self),
                .field("name", HackersPub.HTML?.self),
                .field("handle", String.self),
                .field("avatarUrl", HackersPub.URL.self),
              ] }
              @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                PostDetailQuery.Data.Node.AsPost.SharedPost.Actor.self
              ] }

              public var id: HackersPub.ID { __data["id"] }
              public var name: HackersPub.HTML? { __data["name"] }
              public var handle: String { __data["handle"] }
              public var avatarUrl: HackersPub.URL { __data["avatarUrl"] }
            }

            /// Node.AsPost.SharedPost.Medium
            ///
            /// Parent Type: `PostMedium`
            public struct Medium: HackersPub.SelectionSet {
              @_spi(Unsafe) public let __data: DataDict
              @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

              @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.PostMedium }
              @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
                .field("__typename", String.self),
                .field("url", HackersPub.URL.self),
                .field("thumbnailUrl", String?.self),
                .field("alt", String?.self),
                .field("height", Int?.self),
                .field("width", Int?.self),
              ] }
              @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                PostDetailQuery.Data.Node.AsPost.SharedPost.Medium.self
              ] }

              public var url: HackersPub.URL { __data["url"] }
              public var thumbnailUrl: String? { __data["thumbnailUrl"] }
              public var alt: String? { __data["alt"] }
              public var height: Int? { __data["height"] }
              public var width: Int? { __data["width"] }
            }

            /// Node.AsPost.SharedPost.EngagementStats
            ///
            /// Parent Type: `PostEngagementStats`
            public struct EngagementStats: HackersPub.SelectionSet {
              @_spi(Unsafe) public let __data: DataDict
              @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

              @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.PostEngagementStats }
              @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
                .field("__typename", String.self),
                .field("replies", Int.self),
                .field("reactions", Int.self),
                .field("shares", Int.self),
                .field("quotes", Int.self),
              ] }
              @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                PostDetailQuery.Data.Node.AsPost.SharedPost.EngagementStats.self
              ] }

              public var replies: Int { __data["replies"] }
              public var reactions: Int { __data["reactions"] }
              public var shares: Int { __data["shares"] }
              public var quotes: Int { __data["quotes"] }
            }
          }

          /// Node.AsPost.EngagementStats
          ///
          /// Parent Type: `PostEngagementStats`
          public struct EngagementStats: HackersPub.SelectionSet {
            @_spi(Unsafe) public let __data: DataDict
            @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

            @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.PostEngagementStats }
            @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
              .field("__typename", String.self),
              .field("replies", Int.self),
              .field("reactions", Int.self),
              .field("shares", Int.self),
              .field("quotes", Int.self),
            ] }
            @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
              PostDetailQuery.Data.Node.AsPost.EngagementStats.self
            ] }

            public var replies: Int { __data["replies"] }
            public var reactions: Int { __data["reactions"] }
            public var shares: Int { __data["shares"] }
            public var quotes: Int { __data["quotes"] }
          }

          /// Node.AsPost.ReactionGroup
          ///
          /// Parent Type: `ReactionGroup`
          public struct ReactionGroup: HackersPub.SelectionSet {
            @_spi(Unsafe) public let __data: DataDict
            @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

            @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Interfaces.ReactionGroup }
            @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
              .field("__typename", String.self),
              .inlineFragment(AsEmojiReactionGroup.self),
              .inlineFragment(AsCustomEmojiReactionGroup.self),
            ] }
            @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
              PostDetailQuery.Data.Node.AsPost.ReactionGroup.self
            ] }

            public var asEmojiReactionGroup: AsEmojiReactionGroup? { _asInlineFragment() }
            public var asCustomEmojiReactionGroup: AsCustomEmojiReactionGroup? { _asInlineFragment() }

            /// Node.AsPost.ReactionGroup.AsEmojiReactionGroup
            ///
            /// Parent Type: `EmojiReactionGroup`
            public struct AsEmojiReactionGroup: HackersPub.InlineFragment {
              @_spi(Unsafe) public let __data: DataDict
              @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

              public typealias RootEntityType = PostDetailQuery.Data.Node.AsPost.ReactionGroup
              @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.EmojiReactionGroup }
              @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
                .field("emoji", String.self),
                .field("reactors", Reactors.self, arguments: ["first": 20]),
              ] }
              @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                PostDetailQuery.Data.Node.AsPost.ReactionGroup.self,
                PostDetailQuery.Data.Node.AsPost.ReactionGroup.AsEmojiReactionGroup.self
              ] }

              public var emoji: String { __data["emoji"] }
              public var reactors: Reactors { __data["reactors"] }

              /// Node.AsPost.ReactionGroup.AsEmojiReactionGroup.Reactors
              ///
              /// Parent Type: `ReactionGroupReactorsConnection`
              public struct Reactors: HackersPub.SelectionSet {
                @_spi(Unsafe) public let __data: DataDict
                @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

                @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.ReactionGroupReactorsConnection }
                @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
                  .field("__typename", String.self),
                  .field("edges", [Edge].self),
                  .field("pageInfo", PageInfo.self),
                  .field("totalCount", Int.self),
                ] }
                @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                  PostDetailQuery.Data.Node.AsPost.ReactionGroup.AsEmojiReactionGroup.Reactors.self
                ] }

                public var edges: [Edge] { __data["edges"] }
                public var pageInfo: PageInfo { __data["pageInfo"] }
                public var totalCount: Int { __data["totalCount"] }

                /// Node.AsPost.ReactionGroup.AsEmojiReactionGroup.Reactors.Edge
                ///
                /// Parent Type: `ReactionGroupReactorsConnectionEdge`
                public struct Edge: HackersPub.SelectionSet {
                  @_spi(Unsafe) public let __data: DataDict
                  @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

                  @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.ReactionGroupReactorsConnectionEdge }
                  @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
                    .field("__typename", String.self),
                    .field("node", Node.self),
                  ] }
                  @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                    PostDetailQuery.Data.Node.AsPost.ReactionGroup.AsEmojiReactionGroup.Reactors.Edge.self
                  ] }

                  public var node: Node { __data["node"] }

                  /// Node.AsPost.ReactionGroup.AsEmojiReactionGroup.Reactors.Edge.Node
                  ///
                  /// Parent Type: `Actor`
                  public struct Node: HackersPub.SelectionSet {
                    @_spi(Unsafe) public let __data: DataDict
                    @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

                    @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Actor }
                    @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
                      .field("__typename", String.self),
                      .field("id", HackersPub.ID.self),
                      .field("name", HackersPub.HTML?.self),
                      .field("handle", String.self),
                      .field("avatarUrl", HackersPub.URL.self),
                    ] }
                    @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                      PostDetailQuery.Data.Node.AsPost.ReactionGroup.AsEmojiReactionGroup.Reactors.Edge.Node.self
                    ] }

                    public var id: HackersPub.ID { __data["id"] }
                    public var name: HackersPub.HTML? { __data["name"] }
                    public var handle: String { __data["handle"] }
                    public var avatarUrl: HackersPub.URL { __data["avatarUrl"] }
                  }
                }

                /// Node.AsPost.ReactionGroup.AsEmojiReactionGroup.Reactors.PageInfo
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
                    PostDetailQuery.Data.Node.AsPost.ReactionGroup.AsEmojiReactionGroup.Reactors.PageInfo.self
                  ] }

                  public var hasNextPage: Bool { __data["hasNextPage"] }
                  public var endCursor: String? { __data["endCursor"] }
                }
              }
            }

            /// Node.AsPost.ReactionGroup.AsCustomEmojiReactionGroup
            ///
            /// Parent Type: `CustomEmojiReactionGroup`
            public struct AsCustomEmojiReactionGroup: HackersPub.InlineFragment {
              @_spi(Unsafe) public let __data: DataDict
              @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

              public typealias RootEntityType = PostDetailQuery.Data.Node.AsPost.ReactionGroup
              @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.CustomEmojiReactionGroup }
              @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
                .field("customEmoji", CustomEmoji.self),
                .field("reactors", Reactors.self, arguments: ["first": 20]),
              ] }
              @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                PostDetailQuery.Data.Node.AsPost.ReactionGroup.self,
                PostDetailQuery.Data.Node.AsPost.ReactionGroup.AsCustomEmojiReactionGroup.self
              ] }

              public var customEmoji: CustomEmoji { __data["customEmoji"] }
              public var reactors: Reactors { __data["reactors"] }

              /// Node.AsPost.ReactionGroup.AsCustomEmojiReactionGroup.CustomEmoji
              ///
              /// Parent Type: `CustomEmoji`
              public struct CustomEmoji: HackersPub.SelectionSet {
                @_spi(Unsafe) public let __data: DataDict
                @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

                @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.CustomEmoji }
                @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
                  .field("__typename", String.self),
                  .field("id", HackersPub.ID.self),
                  .field("name", String.self),
                  .field("imageUrl", String.self),
                ] }
                @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                  PostDetailQuery.Data.Node.AsPost.ReactionGroup.AsCustomEmojiReactionGroup.CustomEmoji.self
                ] }

                public var id: HackersPub.ID { __data["id"] }
                public var name: String { __data["name"] }
                public var imageUrl: String { __data["imageUrl"] }
              }

              /// Node.AsPost.ReactionGroup.AsCustomEmojiReactionGroup.Reactors
              ///
              /// Parent Type: `ReactionGroupReactorsConnection`
              public struct Reactors: HackersPub.SelectionSet {
                @_spi(Unsafe) public let __data: DataDict
                @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

                @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.ReactionGroupReactorsConnection }
                @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
                  .field("__typename", String.self),
                  .field("edges", [Edge].self),
                  .field("pageInfo", PageInfo.self),
                  .field("totalCount", Int.self),
                ] }
                @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                  PostDetailQuery.Data.Node.AsPost.ReactionGroup.AsCustomEmojiReactionGroup.Reactors.self
                ] }

                public var edges: [Edge] { __data["edges"] }
                public var pageInfo: PageInfo { __data["pageInfo"] }
                public var totalCount: Int { __data["totalCount"] }

                /// Node.AsPost.ReactionGroup.AsCustomEmojiReactionGroup.Reactors.Edge
                ///
                /// Parent Type: `ReactionGroupReactorsConnectionEdge`
                public struct Edge: HackersPub.SelectionSet {
                  @_spi(Unsafe) public let __data: DataDict
                  @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

                  @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.ReactionGroupReactorsConnectionEdge }
                  @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
                    .field("__typename", String.self),
                    .field("node", Node.self),
                  ] }
                  @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                    PostDetailQuery.Data.Node.AsPost.ReactionGroup.AsCustomEmojiReactionGroup.Reactors.Edge.self
                  ] }

                  public var node: Node { __data["node"] }

                  /// Node.AsPost.ReactionGroup.AsCustomEmojiReactionGroup.Reactors.Edge.Node
                  ///
                  /// Parent Type: `Actor`
                  public struct Node: HackersPub.SelectionSet {
                    @_spi(Unsafe) public let __data: DataDict
                    @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

                    @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Actor }
                    @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
                      .field("__typename", String.self),
                      .field("id", HackersPub.ID.self),
                      .field("name", HackersPub.HTML?.self),
                      .field("handle", String.self),
                      .field("avatarUrl", HackersPub.URL.self),
                    ] }
                    @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                      PostDetailQuery.Data.Node.AsPost.ReactionGroup.AsCustomEmojiReactionGroup.Reactors.Edge.Node.self
                    ] }

                    public var id: HackersPub.ID { __data["id"] }
                    public var name: HackersPub.HTML? { __data["name"] }
                    public var handle: String { __data["handle"] }
                    public var avatarUrl: HackersPub.URL { __data["avatarUrl"] }
                  }
                }

                /// Node.AsPost.ReactionGroup.AsCustomEmojiReactionGroup.Reactors.PageInfo
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
                    PostDetailQuery.Data.Node.AsPost.ReactionGroup.AsCustomEmojiReactionGroup.Reactors.PageInfo.self
                  ] }

                  public var hasNextPage: Bool { __data["hasNextPage"] }
                  public var endCursor: String? { __data["endCursor"] }
                }
              }
            }
          }

          /// Node.AsPost.Replies
          ///
          /// Parent Type: `PostRepliesConnection`
          public struct Replies: HackersPub.SelectionSet {
            @_spi(Unsafe) public let __data: DataDict
            @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

            @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.PostRepliesConnection }
            @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
              .field("__typename", String.self),
              .field("edges", [Edge].self),
              .field("pageInfo", PageInfo.self),
            ] }
            @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
              PostDetailQuery.Data.Node.AsPost.Replies.self
            ] }

            public var edges: [Edge] { __data["edges"] }
            public var pageInfo: PageInfo { __data["pageInfo"] }

            /// Node.AsPost.Replies.Edge
            ///
            /// Parent Type: `PostRepliesConnectionEdge`
            public struct Edge: HackersPub.SelectionSet {
              @_spi(Unsafe) public let __data: DataDict
              @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

              @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.PostRepliesConnectionEdge }
              @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
                .field("__typename", String.self),
                .field("cursor", String.self),
                .field("node", Node.self),
              ] }
              @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                PostDetailQuery.Data.Node.AsPost.Replies.Edge.self
              ] }

              public var cursor: String { __data["cursor"] }
              public var node: Node { __data["node"] }

              /// Node.AsPost.Replies.Edge.Node
              ///
              /// Parent Type: `Post`
              public struct Node: HackersPub.SelectionSet {
                @_spi(Unsafe) public let __data: DataDict
                @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

                @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Interfaces.Post }
                @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
                  .field("__typename", String.self),
                  .field("id", HackersPub.ID.self),
                  .field("name", String?.self),
                  .field("published", HackersPub.DateTime.self),
                  .field("summary", String?.self),
                  .field("content", HackersPub.HTML.self),
                  .field("url", HackersPub.URL?.self),
                  .field("actor", Actor.self),
                  .field("media", [Medium].self),
                  .field("sharedPost", SharedPost?.self),
                  .field("engagementStats", EngagementStats.self),
                ] }
                @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                  PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.self
                ] }

                public var id: HackersPub.ID { __data["id"] }
                public var name: String? { __data["name"] }
                public var published: HackersPub.DateTime { __data["published"] }
                public var summary: String? { __data["summary"] }
                public var content: HackersPub.HTML { __data["content"] }
                public var url: HackersPub.URL? { __data["url"] }
                public var actor: Actor { __data["actor"] }
                public var media: [Medium] { __data["media"] }
                public var sharedPost: SharedPost? { __data["sharedPost"] }
                public var engagementStats: EngagementStats { __data["engagementStats"] }

                /// Node.AsPost.Replies.Edge.Node.Actor
                ///
                /// Parent Type: `Actor`
                public struct Actor: HackersPub.SelectionSet {
                  @_spi(Unsafe) public let __data: DataDict
                  @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

                  @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Actor }
                  @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
                    .field("__typename", String.self),
                    .field("id", HackersPub.ID.self),
                    .field("name", HackersPub.HTML?.self),
                    .field("handle", String.self),
                    .field("avatarUrl", HackersPub.URL.self),
                  ] }
                  @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                    PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.Actor.self
                  ] }

                  public var id: HackersPub.ID { __data["id"] }
                  public var name: HackersPub.HTML? { __data["name"] }
                  public var handle: String { __data["handle"] }
                  public var avatarUrl: HackersPub.URL { __data["avatarUrl"] }
                }

                /// Node.AsPost.Replies.Edge.Node.Medium
                ///
                /// Parent Type: `PostMedium`
                public struct Medium: HackersPub.SelectionSet {
                  @_spi(Unsafe) public let __data: DataDict
                  @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

                  @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.PostMedium }
                  @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
                    .field("__typename", String.self),
                    .field("url", HackersPub.URL.self),
                    .field("thumbnailUrl", String?.self),
                    .field("alt", String?.self),
                    .field("height", Int?.self),
                    .field("width", Int?.self),
                  ] }
                  @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                    PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.Medium.self
                  ] }

                  public var url: HackersPub.URL { __data["url"] }
                  public var thumbnailUrl: String? { __data["thumbnailUrl"] }
                  public var alt: String? { __data["alt"] }
                  public var height: Int? { __data["height"] }
                  public var width: Int? { __data["width"] }
                }

                /// Node.AsPost.Replies.Edge.Node.SharedPost
                ///
                /// Parent Type: `Post`
                public struct SharedPost: HackersPub.SelectionSet {
                  @_spi(Unsafe) public let __data: DataDict
                  @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

                  @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Interfaces.Post }
                  @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
                    .field("__typename", String.self),
                    .field("id", HackersPub.ID.self),
                    .field("name", String?.self),
                    .field("published", HackersPub.DateTime.self),
                    .field("summary", String?.self),
                    .field("content", HackersPub.HTML.self),
                    .field("url", HackersPub.URL?.self),
                    .field("actor", Actor.self),
                    .field("media", [Medium].self),
                    .field("engagementStats", EngagementStats.self),
                  ] }
                  @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                    PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.SharedPost.self
                  ] }

                  public var id: HackersPub.ID { __data["id"] }
                  public var name: String? { __data["name"] }
                  public var published: HackersPub.DateTime { __data["published"] }
                  public var summary: String? { __data["summary"] }
                  public var content: HackersPub.HTML { __data["content"] }
                  public var url: HackersPub.URL? { __data["url"] }
                  public var actor: Actor { __data["actor"] }
                  public var media: [Medium] { __data["media"] }
                  public var engagementStats: EngagementStats { __data["engagementStats"] }

                  /// Node.AsPost.Replies.Edge.Node.SharedPost.Actor
                  ///
                  /// Parent Type: `Actor`
                  public struct Actor: HackersPub.SelectionSet {
                    @_spi(Unsafe) public let __data: DataDict
                    @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

                    @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Actor }
                    @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
                      .field("__typename", String.self),
                      .field("id", HackersPub.ID.self),
                      .field("name", HackersPub.HTML?.self),
                      .field("handle", String.self),
                      .field("avatarUrl", HackersPub.URL.self),
                    ] }
                    @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                      PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.SharedPost.Actor.self
                    ] }

                    public var id: HackersPub.ID { __data["id"] }
                    public var name: HackersPub.HTML? { __data["name"] }
                    public var handle: String { __data["handle"] }
                    public var avatarUrl: HackersPub.URL { __data["avatarUrl"] }
                  }

                  /// Node.AsPost.Replies.Edge.Node.SharedPost.Medium
                  ///
                  /// Parent Type: `PostMedium`
                  public struct Medium: HackersPub.SelectionSet {
                    @_spi(Unsafe) public let __data: DataDict
                    @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

                    @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.PostMedium }
                    @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
                      .field("__typename", String.self),
                      .field("url", HackersPub.URL.self),
                      .field("thumbnailUrl", String?.self),
                      .field("alt", String?.self),
                      .field("height", Int?.self),
                      .field("width", Int?.self),
                    ] }
                    @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                      PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.SharedPost.Medium.self
                    ] }

                    public var url: HackersPub.URL { __data["url"] }
                    public var thumbnailUrl: String? { __data["thumbnailUrl"] }
                    public var alt: String? { __data["alt"] }
                    public var height: Int? { __data["height"] }
                    public var width: Int? { __data["width"] }
                  }

                  /// Node.AsPost.Replies.Edge.Node.SharedPost.EngagementStats
                  ///
                  /// Parent Type: `PostEngagementStats`
                  public struct EngagementStats: HackersPub.SelectionSet {
                    @_spi(Unsafe) public let __data: DataDict
                    @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

                    @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.PostEngagementStats }
                    @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
                      .field("__typename", String.self),
                      .field("replies", Int.self),
                      .field("reactions", Int.self),
                      .field("shares", Int.self),
                      .field("quotes", Int.self),
                    ] }
                    @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                      PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.SharedPost.EngagementStats.self
                    ] }

                    public var replies: Int { __data["replies"] }
                    public var reactions: Int { __data["reactions"] }
                    public var shares: Int { __data["shares"] }
                    public var quotes: Int { __data["quotes"] }
                  }
                }

                /// Node.AsPost.Replies.Edge.Node.EngagementStats
                ///
                /// Parent Type: `PostEngagementStats`
                public struct EngagementStats: HackersPub.SelectionSet {
                  @_spi(Unsafe) public let __data: DataDict
                  @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

                  @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.PostEngagementStats }
                  @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
                    .field("__typename", String.self),
                    .field("replies", Int.self),
                    .field("reactions", Int.self),
                    .field("shares", Int.self),
                    .field("quotes", Int.self),
                  ] }
                  @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                    PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.EngagementStats.self
                  ] }

                  public var replies: Int { __data["replies"] }
                  public var reactions: Int { __data["reactions"] }
                  public var shares: Int { __data["shares"] }
                  public var quotes: Int { __data["quotes"] }
                }
              }
            }

            /// Node.AsPost.Replies.PageInfo
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
                PostDetailQuery.Data.Node.AsPost.Replies.PageInfo.self
              ] }

              public var hasNextPage: Bool { __data["hasNextPage"] }
              public var endCursor: String? { __data["endCursor"] }
            }
          }
        }
      }
    }
  }

}