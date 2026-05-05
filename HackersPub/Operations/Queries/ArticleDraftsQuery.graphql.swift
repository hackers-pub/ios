// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI
@_spi(Execution) @_spi(Unsafe) import ApolloAPI

public extension HackersPub {
  struct ArticleDraftsQuery: GraphQLQuery {
    public static let operationName: String = "ArticleDraftsQuery"
    public static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"query ArticleDraftsQuery { viewer { __typename id articleDrafts(first: 50) { __typename edges { __typename node { __typename id title content contentHtml tags created updated } } } } }"#
      ))

    public init() {}

    public struct Data: HackersPub.SelectionSet {
      @_spi(Unsafe) public let __data: DataDict
      @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

      @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Query }
      @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
        .field("viewer", Viewer?.self),
      ] }
      @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
        ArticleDraftsQuery.Data.self
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
          .field("articleDrafts", ArticleDrafts.self, arguments: ["first": 50]),
        ] }
        @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
          ArticleDraftsQuery.Data.Viewer.self
        ] }

        public var id: HackersPub.ID { __data["id"] }
        public var articleDrafts: ArticleDrafts { __data["articleDrafts"] }

        /// Viewer.ArticleDrafts
        ///
        /// Parent Type: `AccountArticleDraftsConnection`
        public struct ArticleDrafts: HackersPub.SelectionSet {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.AccountArticleDraftsConnection }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("__typename", String.self),
            .field("edges", [Edge].self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            ArticleDraftsQuery.Data.Viewer.ArticleDrafts.self
          ] }

          public var edges: [Edge] { __data["edges"] }

          /// Viewer.ArticleDrafts.Edge
          ///
          /// Parent Type: `AccountArticleDraftsConnectionEdge`
          public struct Edge: HackersPub.SelectionSet {
            @_spi(Unsafe) public let __data: DataDict
            @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

            @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.AccountArticleDraftsConnectionEdge }
            @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
              .field("__typename", String.self),
              .field("node", Node.self),
            ] }
            @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
              ArticleDraftsQuery.Data.Viewer.ArticleDrafts.Edge.self
            ] }

            public var node: Node { __data["node"] }

            /// Viewer.ArticleDrafts.Edge.Node
            ///
            /// Parent Type: `ArticleDraft`
            public struct Node: HackersPub.SelectionSet {
              @_spi(Unsafe) public let __data: DataDict
              @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

              @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.ArticleDraft }
              @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
                .field("__typename", String.self),
                .field("id", HackersPub.ID.self),
                .field("title", String.self),
                .field("content", HackersPub.Markdown.self),
                .field("contentHtml", HackersPub.HTML.self),
                .field("tags", [String].self),
                .field("created", HackersPub.DateTime.self),
                .field("updated", HackersPub.DateTime.self),
              ] }
              @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                ArticleDraftsQuery.Data.Viewer.ArticleDrafts.Edge.Node.self
              ] }

              public var id: HackersPub.ID { __data["id"] }
              public var title: String { __data["title"] }
              public var content: HackersPub.Markdown { __data["content"] }
              /// The rendered HTML of the draft's markdown content.
              public var contentHtml: HackersPub.HTML { __data["contentHtml"] }
              public var tags: [String] { __data["tags"] }
              public var created: HackersPub.DateTime { __data["created"] }
              public var updated: HackersPub.DateTime { __data["updated"] }
            }
          }
        }
      }
    }
  }

}