// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI
@_spi(Execution) @_spi(Unsafe) import ApolloAPI

public extension HackersPub {
  struct ArticleDraftQuery: GraphQLQuery {
    public static let operationName: String = "ArticleDraftQuery"
    public static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"query ArticleDraftQuery($id: ID!) { articleDraft(id: $id) { __typename id uuid title content contentHtml tags created updated } }"#
      ))

    public var id: ID

    public init(id: ID) {
      self.id = id
    }

    @_spi(Unsafe) public var __variables: Variables? { ["id": id] }

    public struct Data: HackersPub.SelectionSet {
      @_spi(Unsafe) public let __data: DataDict
      @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

      @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Query }
      @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
        .field("articleDraft", ArticleDraft?.self, arguments: ["id": .variable("id")]),
      ] }
      @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
        ArticleDraftQuery.Data.self
      ] }

      public var articleDraft: ArticleDraft? { __data["articleDraft"] }

      /// ArticleDraft
      ///
      /// Parent Type: `ArticleDraft`
      public struct ArticleDraft: HackersPub.SelectionSet {
        @_spi(Unsafe) public let __data: DataDict
        @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

        @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.ArticleDraft }
        @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .field("id", HackersPub.ID.self),
          .field("uuid", HackersPub.UUID.self),
          .field("title", String.self),
          .field("content", HackersPub.Markdown.self),
          .field("contentHtml", HackersPub.HTML.self),
          .field("tags", [String].self),
          .field("created", HackersPub.DateTime.self),
          .field("updated", HackersPub.DateTime.self),
        ] }
        @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
          ArticleDraftQuery.Data.ArticleDraft.self
        ] }

        public var id: HackersPub.ID { __data["id"] }
        public var uuid: HackersPub.UUID { __data["uuid"] }
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