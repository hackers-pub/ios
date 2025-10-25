// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI
@_spi(Execution) @_spi(Unsafe) import ApolloAPI

public extension HackersPub {
  struct ActorByHandleQuery: GraphQLQuery {
    public static let operationName: String = "ActorByHandleQuery"
    public static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"query ActorByHandleQuery($handle: String!, $after: String) { actorByHandle(handle: $handle, allowLocalHandle: true) { __typename id handle name bio avatarUrl posts(first: 20, after: $after) { __typename edges { __typename cursor node { __typename id name published summary content url actor { __typename id name handle avatarUrl } media { __typename url thumbnailUrl alt height width } sharedPost { __typename id name published summary content url actor { __typename id name handle avatarUrl } media { __typename url thumbnailUrl alt height width } engagementStats { __typename replies reactions shares quotes } mentions(first: 20) { __typename edges { __typename node { __typename handle } } } } engagementStats { __typename replies reactions shares quotes } mentions(first: 20) { __typename edges { __typename node { __typename id handle } } } } } pageInfo { __typename hasNextPage endCursor } } } }"#
      ))

    public var handle: String
    public var after: GraphQLNullable<String>

    public init(
      handle: String,
      after: GraphQLNullable<String>
    ) {
      self.handle = handle
      self.after = after
    }

    @_spi(Unsafe) public var __variables: Variables? { [
      "handle": handle,
      "after": after
    ] }

    public struct Data: HackersPub.SelectionSet {
      @_spi(Unsafe) public let __data: DataDict
      @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

      @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Query }
      @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
        .field("actorByHandle", ActorByHandle?.self, arguments: [
          "handle": .variable("handle"),
          "allowLocalHandle": true
        ]),
      ] }
      @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
        ActorByHandleQuery.Data.self
      ] }

      public var actorByHandle: ActorByHandle? { __data["actorByHandle"] }

      /// ActorByHandle
      ///
      /// Parent Type: `Actor`
      public struct ActorByHandle: HackersPub.SelectionSet {
        @_spi(Unsafe) public let __data: DataDict
        @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

        @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Actor }
        @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .field("id", HackersPub.ID.self),
          .field("handle", String.self),
          .field("name", HackersPub.HTML?.self),
          .field("bio", HackersPub.HTML?.self),
          .field("avatarUrl", HackersPub.URL.self),
          .field("posts", Posts.self, arguments: [
            "first": 20,
            "after": .variable("after")
          ]),
        ] }
        @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
          ActorByHandleQuery.Data.ActorByHandle.self
        ] }

        public var id: HackersPub.ID { __data["id"] }
        public var handle: String { __data["handle"] }
        public var name: HackersPub.HTML? { __data["name"] }
        public var bio: HackersPub.HTML? { __data["bio"] }
        public var avatarUrl: HackersPub.URL { __data["avatarUrl"] }
        public var posts: Posts { __data["posts"] }

        /// ActorByHandle.Posts
        ///
        /// Parent Type: `ActorPostsConnection`
        public struct Posts: HackersPub.SelectionSet {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.ActorPostsConnection }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("__typename", String.self),
            .field("edges", [Edge].self),
            .field("pageInfo", PageInfo.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            ActorByHandleQuery.Data.ActorByHandle.Posts.self
          ] }

          public var edges: [Edge] { __data["edges"] }
          public var pageInfo: PageInfo { __data["pageInfo"] }

          /// ActorByHandle.Posts.Edge
          ///
          /// Parent Type: `ActorPostsConnectionEdge`
          public struct Edge: HackersPub.SelectionSet {
            @_spi(Unsafe) public let __data: DataDict
            @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

            @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.ActorPostsConnectionEdge }
            @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
              .field("__typename", String.self),
              .field("cursor", String.self),
              .field("node", Node.self),
            ] }
            @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
              ActorByHandleQuery.Data.ActorByHandle.Posts.Edge.self
            ] }

            public var cursor: String { __data["cursor"] }
            public var node: Node { __data["node"] }

            /// ActorByHandle.Posts.Edge.Node
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
                .field("mentions", Mentions.self, arguments: ["first": 20]),
              ] }
              @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                ActorByHandleQuery.Data.ActorByHandle.Posts.Edge.Node.self
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
              public var mentions: Mentions { __data["mentions"] }

              /// ActorByHandle.Posts.Edge.Node.Actor
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
                  ActorByHandleQuery.Data.ActorByHandle.Posts.Edge.Node.Actor.self
                ] }

                public var id: HackersPub.ID { __data["id"] }
                public var name: HackersPub.HTML? { __data["name"] }
                public var handle: String { __data["handle"] }
                public var avatarUrl: HackersPub.URL { __data["avatarUrl"] }
              }

              /// ActorByHandle.Posts.Edge.Node.Medium
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
                  ActorByHandleQuery.Data.ActorByHandle.Posts.Edge.Node.Medium.self
                ] }

                public var url: HackersPub.URL { __data["url"] }
                public var thumbnailUrl: String? { __data["thumbnailUrl"] }
                public var alt: String? { __data["alt"] }
                public var height: Int? { __data["height"] }
                public var width: Int? { __data["width"] }
              }

              /// ActorByHandle.Posts.Edge.Node.SharedPost
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
                  .field("mentions", Mentions.self, arguments: ["first": 20]),
                ] }
                @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                  ActorByHandleQuery.Data.ActorByHandle.Posts.Edge.Node.SharedPost.self
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
                public var mentions: Mentions { __data["mentions"] }

                /// ActorByHandle.Posts.Edge.Node.SharedPost.Actor
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
                    ActorByHandleQuery.Data.ActorByHandle.Posts.Edge.Node.SharedPost.Actor.self
                  ] }

                  public var id: HackersPub.ID { __data["id"] }
                  public var name: HackersPub.HTML? { __data["name"] }
                  public var handle: String { __data["handle"] }
                  public var avatarUrl: HackersPub.URL { __data["avatarUrl"] }
                }

                /// ActorByHandle.Posts.Edge.Node.SharedPost.Medium
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
                    ActorByHandleQuery.Data.ActorByHandle.Posts.Edge.Node.SharedPost.Medium.self
                  ] }

                  public var url: HackersPub.URL { __data["url"] }
                  public var thumbnailUrl: String? { __data["thumbnailUrl"] }
                  public var alt: String? { __data["alt"] }
                  public var height: Int? { __data["height"] }
                  public var width: Int? { __data["width"] }
                }

                /// ActorByHandle.Posts.Edge.Node.SharedPost.EngagementStats
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
                    ActorByHandleQuery.Data.ActorByHandle.Posts.Edge.Node.SharedPost.EngagementStats.self
                  ] }

                  public var replies: Int { __data["replies"] }
                  public var reactions: Int { __data["reactions"] }
                  public var shares: Int { __data["shares"] }
                  public var quotes: Int { __data["quotes"] }
                }

                /// ActorByHandle.Posts.Edge.Node.SharedPost.Mentions
                ///
                /// Parent Type: `PostMentionsConnection`
                public struct Mentions: HackersPub.SelectionSet {
                  @_spi(Unsafe) public let __data: DataDict
                  @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

                  @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.PostMentionsConnection }
                  @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
                    .field("__typename", String.self),
                    .field("edges", [Edge].self),
                  ] }
                  @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                    ActorByHandleQuery.Data.ActorByHandle.Posts.Edge.Node.SharedPost.Mentions.self
                  ] }

                  public var edges: [Edge] { __data["edges"] }

                  /// ActorByHandle.Posts.Edge.Node.SharedPost.Mentions.Edge
                  ///
                  /// Parent Type: `PostMentionsConnectionEdge`
                  public struct Edge: HackersPub.SelectionSet {
                    @_spi(Unsafe) public let __data: DataDict
                    @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

                    @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.PostMentionsConnectionEdge }
                    @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
                      .field("__typename", String.self),
                      .field("node", Node.self),
                    ] }
                    @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                      ActorByHandleQuery.Data.ActorByHandle.Posts.Edge.Node.SharedPost.Mentions.Edge.self
                    ] }

                    public var node: Node { __data["node"] }

                    /// ActorByHandle.Posts.Edge.Node.SharedPost.Mentions.Edge.Node
                    ///
                    /// Parent Type: `Actor`
                    public struct Node: HackersPub.SelectionSet {
                      @_spi(Unsafe) public let __data: DataDict
                      @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

                      @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Actor }
                      @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
                        .field("__typename", String.self),
                        .field("handle", String.self),
                      ] }
                      @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                        ActorByHandleQuery.Data.ActorByHandle.Posts.Edge.Node.SharedPost.Mentions.Edge.Node.self
                      ] }

                      public var handle: String { __data["handle"] }
                    }
                  }
                }
              }

              /// ActorByHandle.Posts.Edge.Node.EngagementStats
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
                  ActorByHandleQuery.Data.ActorByHandle.Posts.Edge.Node.EngagementStats.self
                ] }

                public var replies: Int { __data["replies"] }
                public var reactions: Int { __data["reactions"] }
                public var shares: Int { __data["shares"] }
                public var quotes: Int { __data["quotes"] }
              }

              /// ActorByHandle.Posts.Edge.Node.Mentions
              ///
              /// Parent Type: `PostMentionsConnection`
              public struct Mentions: HackersPub.SelectionSet {
                @_spi(Unsafe) public let __data: DataDict
                @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

                @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.PostMentionsConnection }
                @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
                  .field("__typename", String.self),
                  .field("edges", [Edge].self),
                ] }
                @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                  ActorByHandleQuery.Data.ActorByHandle.Posts.Edge.Node.Mentions.self
                ] }

                public var edges: [Edge] { __data["edges"] }

                /// ActorByHandle.Posts.Edge.Node.Mentions.Edge
                ///
                /// Parent Type: `PostMentionsConnectionEdge`
                public struct Edge: HackersPub.SelectionSet {
                  @_spi(Unsafe) public let __data: DataDict
                  @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

                  @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.PostMentionsConnectionEdge }
                  @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
                    .field("__typename", String.self),
                    .field("node", Node.self),
                  ] }
                  @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                    ActorByHandleQuery.Data.ActorByHandle.Posts.Edge.Node.Mentions.Edge.self
                  ] }

                  public var node: Node { __data["node"] }

                  /// ActorByHandle.Posts.Edge.Node.Mentions.Edge.Node
                  ///
                  /// Parent Type: `Actor`
                  public struct Node: HackersPub.SelectionSet {
                    @_spi(Unsafe) public let __data: DataDict
                    @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

                    @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Actor }
                    @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
                      .field("__typename", String.self),
                      .field("id", HackersPub.ID.self),
                      .field("handle", String.self),
                    ] }
                    @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                      ActorByHandleQuery.Data.ActorByHandle.Posts.Edge.Node.Mentions.Edge.Node.self
                    ] }

                    public var id: HackersPub.ID { __data["id"] }
                    public var handle: String { __data["handle"] }
                  }
                }
              }
            }
          }

          /// ActorByHandle.Posts.PageInfo
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
              ActorByHandleQuery.Data.ActorByHandle.Posts.PageInfo.self
            ] }

            public var hasNextPage: Bool { __data["hasNextPage"] }
            public var endCursor: String? { __data["endCursor"] }
          }
        }
      }
    }
  }

}