// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI
@_spi(Execution) @_spi(Unsafe) import ApolloAPI

public extension HackersPub {
  struct NotificationsQuery: GraphQLQuery {
    public static let operationName: String = "NotificationsQuery"
    public static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"query NotificationsQuery($after: String) { viewer { __typename id notifications(first: 20, after: $after) { __typename edges { __typename cursor node { __typename id uuid created actors(first: 5) { __typename edges { __typename node { __typename id name handle avatarUrl } } } ... on FollowNotification { id } ... on MentionNotification { post { __typename id name published summary content url media { __typename url thumbnailUrl alt height width } actor { __typename id name handle avatarUrl } engagementStats { __typename replies reactions shares quotes } } } ... on ReplyNotification { post { __typename id name published summary content url media { __typename url thumbnailUrl alt height width } actor { __typename id name handle avatarUrl } engagementStats { __typename replies reactions shares quotes } } } ... on QuoteNotification { post { __typename id name published summary content url media { __typename url thumbnailUrl alt height width } actor { __typename id name handle avatarUrl } engagementStats { __typename replies reactions shares quotes } } } ... on ReactNotification { emoji customEmoji { __typename id name imageUrl } post { __typename id name published summary content url media { __typename url thumbnailUrl alt height width } actor { __typename id name handle avatarUrl } engagementStats { __typename replies reactions shares quotes } } } ... on ShareNotification { post { __typename id name published summary content url media { __typename url thumbnailUrl alt height width } actor { __typename id name handle avatarUrl } engagementStats { __typename replies reactions shares quotes } } } } } pageInfo { __typename hasNextPage endCursor } } } }"#
      ))

    public var after: GraphQLNullable<String>

    public init(after: GraphQLNullable<String>) {
      self.after = after
    }

    @_spi(Unsafe) public var __variables: Variables? { ["after": after] }

    public struct Data: HackersPub.SelectionSet {
      @_spi(Unsafe) public let __data: DataDict
      @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

      @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Query }
      @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
        .field("viewer", Viewer?.self),
      ] }
      @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
        NotificationsQuery.Data.self
      ] }

      public var viewer: Viewer? { __data["viewer"] }

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
          .field("notifications", Notifications.self, arguments: [
            "first": 20,
            "after": .variable("after")
          ]),
        ] }
        @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
          NotificationsQuery.Data.Viewer.self
        ] }

        public var id: HackersPub.ID { __data["id"] }
        public var notifications: Notifications { __data["notifications"] }

        /// Viewer.Notifications
        ///
        /// Parent Type: `AccountNotificationsConnection`
        public struct Notifications: HackersPub.SelectionSet {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.AccountNotificationsConnection }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("__typename", String.self),
            .field("edges", [Edge].self),
            .field("pageInfo", PageInfo.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            NotificationsQuery.Data.Viewer.Notifications.self
          ] }

          public var edges: [Edge] { __data["edges"] }
          public var pageInfo: PageInfo { __data["pageInfo"] }

          /// Viewer.Notifications.Edge
          ///
          /// Parent Type: `AccountNotificationsConnectionEdge`
          public struct Edge: HackersPub.SelectionSet {
            @_spi(Unsafe) public let __data: DataDict
            @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

            @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.AccountNotificationsConnectionEdge }
            @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
              .field("__typename", String.self),
              .field("cursor", String.self),
              .field("node", Node.self),
            ] }
            @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
              NotificationsQuery.Data.Viewer.Notifications.Edge.self
            ] }

            public var cursor: String { __data["cursor"] }
            public var node: Node { __data["node"] }

            /// Viewer.Notifications.Edge.Node
            ///
            /// Parent Type: `Notification`
            public struct Node: HackersPub.SelectionSet {
              @_spi(Unsafe) public let __data: DataDict
              @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

              @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Interfaces.Notification }
              @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
                .field("__typename", String.self),
                .field("id", HackersPub.ID.self),
                .field("uuid", HackersPub.UUID.self),
                .field("created", HackersPub.DateTime.self),
                .field("actors", Actors.self, arguments: ["first": 5]),
                .inlineFragment(AsFollowNotification.self),
                .inlineFragment(AsMentionNotification.self),
                .inlineFragment(AsReplyNotification.self),
                .inlineFragment(AsQuoteNotification.self),
                .inlineFragment(AsReactNotification.self),
                .inlineFragment(AsShareNotification.self),
              ] }
              @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                NotificationsQuery.Data.Viewer.Notifications.Edge.Node.self
              ] }

              public var id: HackersPub.ID { __data["id"] }
              public var uuid: HackersPub.UUID { __data["uuid"] }
              public var created: HackersPub.DateTime { __data["created"] }
              public var actors: Actors { __data["actors"] }

              public var asFollowNotification: AsFollowNotification? { _asInlineFragment() }
              public var asMentionNotification: AsMentionNotification? { _asInlineFragment() }
              public var asReplyNotification: AsReplyNotification? { _asInlineFragment() }
              public var asQuoteNotification: AsQuoteNotification? { _asInlineFragment() }
              public var asReactNotification: AsReactNotification? { _asInlineFragment() }
              public var asShareNotification: AsShareNotification? { _asInlineFragment() }

              /// Viewer.Notifications.Edge.Node.Actors
              ///
              /// Parent Type: `NotificationActorsConnection`
              public struct Actors: HackersPub.SelectionSet {
                @_spi(Unsafe) public let __data: DataDict
                @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

                @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.NotificationActorsConnection }
                @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
                  .field("__typename", String.self),
                  .field("edges", [Edge].self),
                ] }
                @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                  NotificationsQuery.Data.Viewer.Notifications.Edge.Node.Actors.self
                ] }

                public var edges: [Edge] { __data["edges"] }

                /// Viewer.Notifications.Edge.Node.Actors.Edge
                ///
                /// Parent Type: `NotificationActorsConnectionEdge`
                public struct Edge: HackersPub.SelectionSet {
                  @_spi(Unsafe) public let __data: DataDict
                  @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

                  @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.NotificationActorsConnectionEdge }
                  @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
                    .field("__typename", String.self),
                    .field("node", Node.self),
                  ] }
                  @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                    NotificationsQuery.Data.Viewer.Notifications.Edge.Node.Actors.Edge.self
                  ] }

                  public var node: Node { __data["node"] }

                  /// Viewer.Notifications.Edge.Node.Actors.Edge.Node
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
                      NotificationsQuery.Data.Viewer.Notifications.Edge.Node.Actors.Edge.Node.self
                    ] }

                    public var id: HackersPub.ID { __data["id"] }
                    public var name: HackersPub.HTML? { __data["name"] }
                    public var handle: String { __data["handle"] }
                    public var avatarUrl: HackersPub.URL { __data["avatarUrl"] }
                  }
                }
              }

              /// Viewer.Notifications.Edge.Node.AsFollowNotification
              ///
              /// Parent Type: `FollowNotification`
              public struct AsFollowNotification: HackersPub.InlineFragment {
                @_spi(Unsafe) public let __data: DataDict
                @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

                public typealias RootEntityType = NotificationsQuery.Data.Viewer.Notifications.Edge.Node
                @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.FollowNotification }
                @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
                  .field("id", HackersPub.ID.self),
                ] }
                @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                  NotificationsQuery.Data.Viewer.Notifications.Edge.Node.self,
                  NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsFollowNotification.self
                ] }

                public var id: HackersPub.ID { __data["id"] }
                public var uuid: HackersPub.UUID { __data["uuid"] }
                public var created: HackersPub.DateTime { __data["created"] }
                public var actors: Actors { __data["actors"] }
              }

              /// Viewer.Notifications.Edge.Node.AsMentionNotification
              ///
              /// Parent Type: `MentionNotification`
              public struct AsMentionNotification: HackersPub.InlineFragment {
                @_spi(Unsafe) public let __data: DataDict
                @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

                public typealias RootEntityType = NotificationsQuery.Data.Viewer.Notifications.Edge.Node
                @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.MentionNotification }
                @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
                  .field("post", Post?.self),
                ] }
                @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                  NotificationsQuery.Data.Viewer.Notifications.Edge.Node.self,
                  NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsMentionNotification.self
                ] }

                public var post: Post? { __data["post"] }
                public var id: HackersPub.ID { __data["id"] }
                public var uuid: HackersPub.UUID { __data["uuid"] }
                public var created: HackersPub.DateTime { __data["created"] }
                public var actors: Actors { __data["actors"] }

                /// Viewer.Notifications.Edge.Node.AsMentionNotification.Post
                ///
                /// Parent Type: `Post`
                public struct Post: HackersPub.SelectionSet {
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
                    .field("media", [Medium].self),
                    .field("actor", Actor.self),
                    .field("engagementStats", EngagementStats.self),
                  ] }
                  @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                    NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsMentionNotification.Post.self
                  ] }

                  public var id: HackersPub.ID { __data["id"] }
                  public var name: String? { __data["name"] }
                  public var published: HackersPub.DateTime { __data["published"] }
                  public var summary: String? { __data["summary"] }
                  public var content: HackersPub.HTML { __data["content"] }
                  public var url: HackersPub.URL? { __data["url"] }
                  public var media: [Medium] { __data["media"] }
                  public var actor: Actor { __data["actor"] }
                  public var engagementStats: EngagementStats { __data["engagementStats"] }

                  /// Viewer.Notifications.Edge.Node.AsMentionNotification.Post.Medium
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
                      NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsMentionNotification.Post.Medium.self
                    ] }

                    public var url: HackersPub.URL { __data["url"] }
                    public var thumbnailUrl: String? { __data["thumbnailUrl"] }
                    public var alt: String? { __data["alt"] }
                    public var height: Int? { __data["height"] }
                    public var width: Int? { __data["width"] }
                  }

                  /// Viewer.Notifications.Edge.Node.AsMentionNotification.Post.Actor
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
                      NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsMentionNotification.Post.Actor.self
                    ] }

                    public var id: HackersPub.ID { __data["id"] }
                    public var name: HackersPub.HTML? { __data["name"] }
                    public var handle: String { __data["handle"] }
                    public var avatarUrl: HackersPub.URL { __data["avatarUrl"] }
                  }

                  /// Viewer.Notifications.Edge.Node.AsMentionNotification.Post.EngagementStats
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
                      NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsMentionNotification.Post.EngagementStats.self
                    ] }

                    public var replies: Int { __data["replies"] }
                    public var reactions: Int { __data["reactions"] }
                    public var shares: Int { __data["shares"] }
                    public var quotes: Int { __data["quotes"] }
                  }
                }
              }

              /// Viewer.Notifications.Edge.Node.AsReplyNotification
              ///
              /// Parent Type: `ReplyNotification`
              public struct AsReplyNotification: HackersPub.InlineFragment {
                @_spi(Unsafe) public let __data: DataDict
                @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

                public typealias RootEntityType = NotificationsQuery.Data.Viewer.Notifications.Edge.Node
                @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.ReplyNotification }
                @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
                  .field("post", Post?.self),
                ] }
                @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                  NotificationsQuery.Data.Viewer.Notifications.Edge.Node.self,
                  NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsReplyNotification.self
                ] }

                public var post: Post? { __data["post"] }
                public var id: HackersPub.ID { __data["id"] }
                public var uuid: HackersPub.UUID { __data["uuid"] }
                public var created: HackersPub.DateTime { __data["created"] }
                public var actors: Actors { __data["actors"] }

                /// Viewer.Notifications.Edge.Node.AsReplyNotification.Post
                ///
                /// Parent Type: `Post`
                public struct Post: HackersPub.SelectionSet {
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
                    .field("media", [Medium].self),
                    .field("actor", Actor.self),
                    .field("engagementStats", EngagementStats.self),
                  ] }
                  @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                    NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsReplyNotification.Post.self
                  ] }

                  public var id: HackersPub.ID { __data["id"] }
                  public var name: String? { __data["name"] }
                  public var published: HackersPub.DateTime { __data["published"] }
                  public var summary: String? { __data["summary"] }
                  public var content: HackersPub.HTML { __data["content"] }
                  public var url: HackersPub.URL? { __data["url"] }
                  public var media: [Medium] { __data["media"] }
                  public var actor: Actor { __data["actor"] }
                  public var engagementStats: EngagementStats { __data["engagementStats"] }

                  /// Viewer.Notifications.Edge.Node.AsReplyNotification.Post.Medium
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
                      NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsReplyNotification.Post.Medium.self
                    ] }

                    public var url: HackersPub.URL { __data["url"] }
                    public var thumbnailUrl: String? { __data["thumbnailUrl"] }
                    public var alt: String? { __data["alt"] }
                    public var height: Int? { __data["height"] }
                    public var width: Int? { __data["width"] }
                  }

                  /// Viewer.Notifications.Edge.Node.AsReplyNotification.Post.Actor
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
                      NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsReplyNotification.Post.Actor.self
                    ] }

                    public var id: HackersPub.ID { __data["id"] }
                    public var name: HackersPub.HTML? { __data["name"] }
                    public var handle: String { __data["handle"] }
                    public var avatarUrl: HackersPub.URL { __data["avatarUrl"] }
                  }

                  /// Viewer.Notifications.Edge.Node.AsReplyNotification.Post.EngagementStats
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
                      NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsReplyNotification.Post.EngagementStats.self
                    ] }

                    public var replies: Int { __data["replies"] }
                    public var reactions: Int { __data["reactions"] }
                    public var shares: Int { __data["shares"] }
                    public var quotes: Int { __data["quotes"] }
                  }
                }
              }

              /// Viewer.Notifications.Edge.Node.AsQuoteNotification
              ///
              /// Parent Type: `QuoteNotification`
              public struct AsQuoteNotification: HackersPub.InlineFragment {
                @_spi(Unsafe) public let __data: DataDict
                @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

                public typealias RootEntityType = NotificationsQuery.Data.Viewer.Notifications.Edge.Node
                @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.QuoteNotification }
                @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
                  .field("post", Post?.self),
                ] }
                @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                  NotificationsQuery.Data.Viewer.Notifications.Edge.Node.self,
                  NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsQuoteNotification.self
                ] }

                public var post: Post? { __data["post"] }
                public var id: HackersPub.ID { __data["id"] }
                public var uuid: HackersPub.UUID { __data["uuid"] }
                public var created: HackersPub.DateTime { __data["created"] }
                public var actors: Actors { __data["actors"] }

                /// Viewer.Notifications.Edge.Node.AsQuoteNotification.Post
                ///
                /// Parent Type: `Post`
                public struct Post: HackersPub.SelectionSet {
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
                    .field("media", [Medium].self),
                    .field("actor", Actor.self),
                    .field("engagementStats", EngagementStats.self),
                  ] }
                  @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                    NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsQuoteNotification.Post.self
                  ] }

                  public var id: HackersPub.ID { __data["id"] }
                  public var name: String? { __data["name"] }
                  public var published: HackersPub.DateTime { __data["published"] }
                  public var summary: String? { __data["summary"] }
                  public var content: HackersPub.HTML { __data["content"] }
                  public var url: HackersPub.URL? { __data["url"] }
                  public var media: [Medium] { __data["media"] }
                  public var actor: Actor { __data["actor"] }
                  public var engagementStats: EngagementStats { __data["engagementStats"] }

                  /// Viewer.Notifications.Edge.Node.AsQuoteNotification.Post.Medium
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
                      NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsQuoteNotification.Post.Medium.self
                    ] }

                    public var url: HackersPub.URL { __data["url"] }
                    public var thumbnailUrl: String? { __data["thumbnailUrl"] }
                    public var alt: String? { __data["alt"] }
                    public var height: Int? { __data["height"] }
                    public var width: Int? { __data["width"] }
                  }

                  /// Viewer.Notifications.Edge.Node.AsQuoteNotification.Post.Actor
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
                      NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsQuoteNotification.Post.Actor.self
                    ] }

                    public var id: HackersPub.ID { __data["id"] }
                    public var name: HackersPub.HTML? { __data["name"] }
                    public var handle: String { __data["handle"] }
                    public var avatarUrl: HackersPub.URL { __data["avatarUrl"] }
                  }

                  /// Viewer.Notifications.Edge.Node.AsQuoteNotification.Post.EngagementStats
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
                      NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsQuoteNotification.Post.EngagementStats.self
                    ] }

                    public var replies: Int { __data["replies"] }
                    public var reactions: Int { __data["reactions"] }
                    public var shares: Int { __data["shares"] }
                    public var quotes: Int { __data["quotes"] }
                  }
                }
              }

              /// Viewer.Notifications.Edge.Node.AsReactNotification
              ///
              /// Parent Type: `ReactNotification`
              public struct AsReactNotification: HackersPub.InlineFragment {
                @_spi(Unsafe) public let __data: DataDict
                @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

                public typealias RootEntityType = NotificationsQuery.Data.Viewer.Notifications.Edge.Node
                @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.ReactNotification }
                @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
                  .field("emoji", String?.self),
                  .field("customEmoji", CustomEmoji?.self),
                  .field("post", Post?.self),
                ] }
                @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                  NotificationsQuery.Data.Viewer.Notifications.Edge.Node.self,
                  NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsReactNotification.self
                ] }

                public var emoji: String? { __data["emoji"] }
                public var customEmoji: CustomEmoji? { __data["customEmoji"] }
                public var post: Post? { __data["post"] }
                public var id: HackersPub.ID { __data["id"] }
                public var uuid: HackersPub.UUID { __data["uuid"] }
                public var created: HackersPub.DateTime { __data["created"] }
                public var actors: Actors { __data["actors"] }

                /// Viewer.Notifications.Edge.Node.AsReactNotification.CustomEmoji
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
                    NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsReactNotification.CustomEmoji.self
                  ] }

                  public var id: HackersPub.ID { __data["id"] }
                  public var name: String { __data["name"] }
                  public var imageUrl: String { __data["imageUrl"] }
                }

                /// Viewer.Notifications.Edge.Node.AsReactNotification.Post
                ///
                /// Parent Type: `Post`
                public struct Post: HackersPub.SelectionSet {
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
                    .field("media", [Medium].self),
                    .field("actor", Actor.self),
                    .field("engagementStats", EngagementStats.self),
                  ] }
                  @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                    NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsReactNotification.Post.self
                  ] }

                  public var id: HackersPub.ID { __data["id"] }
                  public var name: String? { __data["name"] }
                  public var published: HackersPub.DateTime { __data["published"] }
                  public var summary: String? { __data["summary"] }
                  public var content: HackersPub.HTML { __data["content"] }
                  public var url: HackersPub.URL? { __data["url"] }
                  public var media: [Medium] { __data["media"] }
                  public var actor: Actor { __data["actor"] }
                  public var engagementStats: EngagementStats { __data["engagementStats"] }

                  /// Viewer.Notifications.Edge.Node.AsReactNotification.Post.Medium
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
                      NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsReactNotification.Post.Medium.self
                    ] }

                    public var url: HackersPub.URL { __data["url"] }
                    public var thumbnailUrl: String? { __data["thumbnailUrl"] }
                    public var alt: String? { __data["alt"] }
                    public var height: Int? { __data["height"] }
                    public var width: Int? { __data["width"] }
                  }

                  /// Viewer.Notifications.Edge.Node.AsReactNotification.Post.Actor
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
                      NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsReactNotification.Post.Actor.self
                    ] }

                    public var id: HackersPub.ID { __data["id"] }
                    public var name: HackersPub.HTML? { __data["name"] }
                    public var handle: String { __data["handle"] }
                    public var avatarUrl: HackersPub.URL { __data["avatarUrl"] }
                  }

                  /// Viewer.Notifications.Edge.Node.AsReactNotification.Post.EngagementStats
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
                      NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsReactNotification.Post.EngagementStats.self
                    ] }

                    public var replies: Int { __data["replies"] }
                    public var reactions: Int { __data["reactions"] }
                    public var shares: Int { __data["shares"] }
                    public var quotes: Int { __data["quotes"] }
                  }
                }
              }

              /// Viewer.Notifications.Edge.Node.AsShareNotification
              ///
              /// Parent Type: `ShareNotification`
              public struct AsShareNotification: HackersPub.InlineFragment {
                @_spi(Unsafe) public let __data: DataDict
                @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

                public typealias RootEntityType = NotificationsQuery.Data.Viewer.Notifications.Edge.Node
                @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.ShareNotification }
                @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
                  .field("post", Post?.self),
                ] }
                @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                  NotificationsQuery.Data.Viewer.Notifications.Edge.Node.self,
                  NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsShareNotification.self
                ] }

                public var post: Post? { __data["post"] }
                public var id: HackersPub.ID { __data["id"] }
                public var uuid: HackersPub.UUID { __data["uuid"] }
                public var created: HackersPub.DateTime { __data["created"] }
                public var actors: Actors { __data["actors"] }

                /// Viewer.Notifications.Edge.Node.AsShareNotification.Post
                ///
                /// Parent Type: `Post`
                public struct Post: HackersPub.SelectionSet {
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
                    .field("media", [Medium].self),
                    .field("actor", Actor.self),
                    .field("engagementStats", EngagementStats.self),
                  ] }
                  @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                    NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsShareNotification.Post.self
                  ] }

                  public var id: HackersPub.ID { __data["id"] }
                  public var name: String? { __data["name"] }
                  public var published: HackersPub.DateTime { __data["published"] }
                  public var summary: String? { __data["summary"] }
                  public var content: HackersPub.HTML { __data["content"] }
                  public var url: HackersPub.URL? { __data["url"] }
                  public var media: [Medium] { __data["media"] }
                  public var actor: Actor { __data["actor"] }
                  public var engagementStats: EngagementStats { __data["engagementStats"] }

                  /// Viewer.Notifications.Edge.Node.AsShareNotification.Post.Medium
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
                      NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsShareNotification.Post.Medium.self
                    ] }

                    public var url: HackersPub.URL { __data["url"] }
                    public var thumbnailUrl: String? { __data["thumbnailUrl"] }
                    public var alt: String? { __data["alt"] }
                    public var height: Int? { __data["height"] }
                    public var width: Int? { __data["width"] }
                  }

                  /// Viewer.Notifications.Edge.Node.AsShareNotification.Post.Actor
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
                      NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsShareNotification.Post.Actor.self
                    ] }

                    public var id: HackersPub.ID { __data["id"] }
                    public var name: HackersPub.HTML? { __data["name"] }
                    public var handle: String { __data["handle"] }
                    public var avatarUrl: HackersPub.URL { __data["avatarUrl"] }
                  }

                  /// Viewer.Notifications.Edge.Node.AsShareNotification.Post.EngagementStats
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
                      NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsShareNotification.Post.EngagementStats.self
                    ] }

                    public var replies: Int { __data["replies"] }
                    public var reactions: Int { __data["reactions"] }
                    public var shares: Int { __data["shares"] }
                    public var quotes: Int { __data["quotes"] }
                  }
                }
              }
            }
          }

          /// Viewer.Notifications.PageInfo
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
              NotificationsQuery.Data.Viewer.Notifications.PageInfo.self
            ] }

            public var hasNextPage: Bool { __data["hasNextPage"] }
            public var endCursor: String? { __data["endCursor"] }
          }
        }
      }
    }
  }

}