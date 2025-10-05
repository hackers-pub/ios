// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI
@_spi(Execution) @_spi(Unsafe) import ApolloAPI

public extension HackersPub {
  struct LocalTimelineQuery: GraphQLQuery {
    public static let operationName: String = "LocalTimelineQuery"
    public static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"query LocalTimelineQuery($after: String) { publicTimeline(local: true, first: 20, after: $after) { __typename edges { __typename cursor node { __typename id name published summary content url actor { __typename id name handle avatarUrl } media { __typename url thumbnailUrl alt height width } sharedPost { __typename id name published summary content url actor { __typename id name handle avatarUrl } media { __typename url thumbnailUrl alt height width } } } } pageInfo { __typename hasNextPage endCursor } } }"#
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
        .field("publicTimeline", PublicTimeline.self, arguments: [
          "local": true,
          "first": 20,
          "after": .variable("after")
        ]),
      ] }
      @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
        LocalTimelineQuery.Data.self
      ] }

      public var publicTimeline: PublicTimeline { __data["publicTimeline"] }

      /// PublicTimeline
      ///
      /// Parent Type: `QueryPublicTimelineConnection`
      public struct PublicTimeline: HackersPub.SelectionSet {
        @_spi(Unsafe) public let __data: DataDict
        @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

        @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.QueryPublicTimelineConnection }
        @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .field("edges", [Edge].self),
          .field("pageInfo", PageInfo.self),
        ] }
        @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
          LocalTimelineQuery.Data.PublicTimeline.self
        ] }

        public var edges: [Edge] { __data["edges"] }
        public var pageInfo: PageInfo { __data["pageInfo"] }

        /// PublicTimeline.Edge
        ///
        /// Parent Type: `QueryPublicTimelineConnectionEdge`
        public struct Edge: HackersPub.SelectionSet {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.QueryPublicTimelineConnectionEdge }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("__typename", String.self),
            .field("cursor", String.self),
            .field("node", Node.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            LocalTimelineQuery.Data.PublicTimeline.Edge.self
          ] }

          public var cursor: String { __data["cursor"] }
          public var node: Node { __data["node"] }

          /// PublicTimeline.Edge.Node
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
            ] }
            @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
              LocalTimelineQuery.Data.PublicTimeline.Edge.Node.self
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

            /// PublicTimeline.Edge.Node.Actor
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
                LocalTimelineQuery.Data.PublicTimeline.Edge.Node.Actor.self
              ] }

              public var id: HackersPub.ID { __data["id"] }
              public var name: HackersPub.HTML? { __data["name"] }
              public var handle: String { __data["handle"] }
              public var avatarUrl: HackersPub.URL { __data["avatarUrl"] }
            }

            /// PublicTimeline.Edge.Node.Medium
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
                LocalTimelineQuery.Data.PublicTimeline.Edge.Node.Medium.self
              ] }

              public var url: HackersPub.URL { __data["url"] }
              public var thumbnailUrl: String? { __data["thumbnailUrl"] }
              public var alt: String? { __data["alt"] }
              public var height: Int? { __data["height"] }
              public var width: Int? { __data["width"] }
            }

            /// PublicTimeline.Edge.Node.SharedPost
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
              ] }
              @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                LocalTimelineQuery.Data.PublicTimeline.Edge.Node.SharedPost.self
              ] }

              public var id: HackersPub.ID { __data["id"] }
              public var name: String? { __data["name"] }
              public var published: HackersPub.DateTime { __data["published"] }
              public var summary: String? { __data["summary"] }
              public var content: HackersPub.HTML { __data["content"] }
              public var url: HackersPub.URL? { __data["url"] }
              public var actor: Actor { __data["actor"] }
              public var media: [Medium] { __data["media"] }

              /// PublicTimeline.Edge.Node.SharedPost.Actor
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
                  LocalTimelineQuery.Data.PublicTimeline.Edge.Node.SharedPost.Actor.self
                ] }

                public var id: HackersPub.ID { __data["id"] }
                public var name: HackersPub.HTML? { __data["name"] }
                public var handle: String { __data["handle"] }
                public var avatarUrl: HackersPub.URL { __data["avatarUrl"] }
              }

              /// PublicTimeline.Edge.Node.SharedPost.Medium
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
                  LocalTimelineQuery.Data.PublicTimeline.Edge.Node.SharedPost.Medium.self
                ] }

                public var url: HackersPub.URL { __data["url"] }
                public var thumbnailUrl: String? { __data["thumbnailUrl"] }
                public var alt: String? { __data["alt"] }
                public var height: Int? { __data["height"] }
                public var width: Int? { __data["width"] }
              }
            }
          }
        }

        /// PublicTimeline.PageInfo
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
            LocalTimelineQuery.Data.PublicTimeline.PageInfo.self
          ] }

          public var hasNextPage: Bool { __data["hasNextPage"] }
          public var endCursor: String? { __data["endCursor"] }
        }
      }
    }
  }

}