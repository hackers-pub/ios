// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI
@_spi(Execution) @_spi(Unsafe) import ApolloAPI

public extension HackersPub {
  struct ActorArticlesQuery: GraphQLQuery {
    public static let operationName: String = "ActorArticlesQuery"
    public static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"query ActorArticlesQuery($handle: String!, $after: String, $before: String, $first: Int, $last: Int) { actorByHandle(handle: $handle, allowLocalHandle: true) { __typename id articles(first: $first, after: $after, before: $before, last: $last) { __typename edges { __typename cursor node { __typename ...ProfilePostFields } } pageInfo { __typename hasPreviousPage hasNextPage startCursor endCursor } } } }"#,
        fragments: [ProfilePostFields.self]
      ))

    public var handle: String
    public var after: GraphQLNullable<String>
    public var before: GraphQLNullable<String>
    public var first: GraphQLNullable<Int32>
    public var last: GraphQLNullable<Int32>

    public init(
      handle: String,
      after: GraphQLNullable<String>,
      before: GraphQLNullable<String>,
      first: GraphQLNullable<Int32>,
      last: GraphQLNullable<Int32>
    ) {
      self.handle = handle
      self.after = after
      self.before = before
      self.first = first
      self.last = last
    }

    @_spi(Unsafe) public var __variables: Variables? { [
      "handle": handle,
      "after": after,
      "before": before,
      "first": first,
      "last": last
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
        ActorArticlesQuery.Data.self
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
          .field("articles", Articles.self, arguments: [
            "first": .variable("first"),
            "after": .variable("after"),
            "before": .variable("before"),
            "last": .variable("last")
          ]),
        ] }
        @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
          ActorArticlesQuery.Data.ActorByHandle.self
        ] }

        public var id: HackersPub.ID { __data["id"] }
        public var articles: Articles { __data["articles"] }

        /// ActorByHandle.Articles
        ///
        /// Parent Type: `ActorArticlesConnection`
        public struct Articles: HackersPub.SelectionSet {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.ActorArticlesConnection }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("__typename", String.self),
            .field("edges", [Edge].self),
            .field("pageInfo", PageInfo.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            ActorArticlesQuery.Data.ActorByHandle.Articles.self
          ] }

          public var edges: [Edge] { __data["edges"] }
          public var pageInfo: PageInfo { __data["pageInfo"] }

          /// ActorByHandle.Articles.Edge
          ///
          /// Parent Type: `ActorArticlesConnectionEdge`
          public struct Edge: HackersPub.SelectionSet {
            @_spi(Unsafe) public let __data: DataDict
            @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

            @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.ActorArticlesConnectionEdge }
            @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
              .field("__typename", String.self),
              .field("cursor", String.self),
              .field("node", Node.self),
            ] }
            @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
              ActorArticlesQuery.Data.ActorByHandle.Articles.Edge.self
            ] }

            public var cursor: String { __data["cursor"] }
            public var node: Node { __data["node"] }

            /// ActorByHandle.Articles.Edge.Node
            ///
            /// Parent Type: `Article`
            public struct Node: HackersPub.SelectionSet {
              @_spi(Unsafe) public let __data: DataDict
              @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

              @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Article }
              @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
                .field("__typename", String.self),
                .fragment(ProfilePostFields.self),
              ] }
              @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                ActorArticlesQuery.Data.ActorByHandle.Articles.Edge.Node.self,
                ProfilePostFields.self
              ] }

              public var id: HackersPub.ID { __data["id"] }
              public var name: String? { __data["name"] }
              public var published: HackersPub.DateTime { __data["published"] }
              public var summary: String? { __data["summary"] }
              public var content: HackersPub.HTML { __data["content"] }
              public var excerpt: String { __data["excerpt"] }
              public var url: HackersPub.URL? { __data["url"] }
              public var iri: HackersPub.URL { __data["iri"] }
              public var viewerHasShared: Bool { __data["viewerHasShared"] }
              public var viewerHasBookmarked: Bool { __data["viewerHasBookmarked"] }
              public var actor: Actor { __data["actor"] }
              public var media: [Medium] { __data["media"] }
              public var sharedPost: SharedPost? { __data["sharedPost"] }
              public var quotedPost: QuotedPost? { __data["quotedPost"] }
              public var engagementStats: EngagementStats { __data["engagementStats"] }
              public var reactionGroups: [ReactionGroup] { __data["reactionGroups"] }
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

          /// ActorByHandle.Articles.PageInfo
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
              ActorArticlesQuery.Data.ActorByHandle.Articles.PageInfo.self
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

}