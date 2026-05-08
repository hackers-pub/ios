// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI
@_spi(Execution) @_spi(Unsafe) import ApolloAPI

public extension HackersPub {
  struct BookmarksQuery: GraphQLQuery {
    public static let operationName: String = "BookmarksQuery"
    public static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"query BookmarksQuery($after: String, $postType: PostType) { bookmarks(first: 20, after: $after, postType: $postType) { __typename edges { __typename cursor node { __typename ...ProfilePostFields } } pageInfo { __typename hasNextPage endCursor } } }"#,
        fragments: [ProfilePostFields.self]
      ))

    public var after: GraphQLNullable<String>
    public var postType: GraphQLNullable<GraphQLEnum<PostType>>

    public init(
      after: GraphQLNullable<String>,
      postType: GraphQLNullable<GraphQLEnum<PostType>>
    ) {
      self.after = after
      self.postType = postType
    }

    @_spi(Unsafe) public var __variables: Variables? { [
      "after": after,
      "postType": postType
    ] }

    public struct Data: HackersPub.SelectionSet {
      @_spi(Unsafe) public let __data: DataDict
      @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

      @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Query }
      @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
        .field("bookmarks", Bookmarks.self, arguments: [
          "first": 20,
          "after": .variable("after"),
          "postType": .variable("postType")
        ]),
      ] }
      @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
        BookmarksQuery.Data.self
      ] }

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

        /// Bookmarks.PageInfo
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
            BookmarksQuery.Data.Bookmarks.PageInfo.self
          ] }

          public var hasNextPage: Bool { __data["hasNextPage"] }
          public var endCursor: String? { __data["endCursor"] }
        }
      }
    }
  }

}