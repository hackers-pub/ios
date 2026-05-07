// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI
@_spi(Execution) @_spi(Unsafe) import ApolloAPI

public extension HackersPub {
  struct SaveArticleDraftMutation: GraphQLMutation {
    public static let operationName: String = "SaveArticleDraftMutation"
    public static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"mutation SaveArticleDraftMutation($title: String!, $content: Markdown!, $tags: [String!]!, $id: ID) { saveArticleDraft( input: { title: $title, content: $content, tags: $tags, id: $id } ) { __typename ... on SaveArticleDraftPayload { draft { __typename id uuid title content contentHtml tags created updated } } ... on InvalidInputError { inputPath } ... on NotAuthenticatedError { notAuthenticated } } }"#
      ))

    public var title: String
    public var content: Markdown
    public var tags: [String]
    public var id: GraphQLNullable<ID>

    public init(
      title: String,
      content: Markdown,
      tags: [String],
      id: GraphQLNullable<ID>
    ) {
      self.title = title
      self.content = content
      self.tags = tags
      self.id = id
    }

    @_spi(Unsafe) public var __variables: Variables? { [
      "title": title,
      "content": content,
      "tags": tags,
      "id": id
    ] }

    public struct Data: HackersPub.SelectionSet {
      @_spi(Unsafe) public let __data: DataDict
      @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

      @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Mutation }
      @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
        .field("saveArticleDraft", SaveArticleDraft.self, arguments: ["input": [
          "title": .variable("title"),
          "content": .variable("content"),
          "tags": .variable("tags"),
          "id": .variable("id")
        ]]),
      ] }
      @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
        SaveArticleDraftMutation.Data.self
      ] }

      public var saveArticleDraft: SaveArticleDraft { __data["saveArticleDraft"] }

      /// SaveArticleDraft
      ///
      /// Parent Type: `SaveArticleDraftResult`
      public struct SaveArticleDraft: HackersPub.SelectionSet {
        @_spi(Unsafe) public let __data: DataDict
        @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

        @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Unions.SaveArticleDraftResult }
        @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .inlineFragment(AsSaveArticleDraftPayload.self),
          .inlineFragment(AsInvalidInputError.self),
          .inlineFragment(AsNotAuthenticatedError.self),
        ] }
        @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
          SaveArticleDraftMutation.Data.SaveArticleDraft.self
        ] }

        public var asSaveArticleDraftPayload: AsSaveArticleDraftPayload? { _asInlineFragment() }
        public var asInvalidInputError: AsInvalidInputError? { _asInlineFragment() }
        public var asNotAuthenticatedError: AsNotAuthenticatedError? { _asInlineFragment() }

        /// SaveArticleDraft.AsSaveArticleDraftPayload
        ///
        /// Parent Type: `SaveArticleDraftPayload`
        public struct AsSaveArticleDraftPayload: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = SaveArticleDraftMutation.Data.SaveArticleDraft
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.SaveArticleDraftPayload }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("draft", Draft.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            SaveArticleDraftMutation.Data.SaveArticleDraft.self,
            SaveArticleDraftMutation.Data.SaveArticleDraft.AsSaveArticleDraftPayload.self
          ] }

          public var draft: Draft { __data["draft"] }

          /// SaveArticleDraft.AsSaveArticleDraftPayload.Draft
          ///
          /// Parent Type: `ArticleDraft`
          public struct Draft: HackersPub.SelectionSet {
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
              SaveArticleDraftMutation.Data.SaveArticleDraft.AsSaveArticleDraftPayload.Draft.self
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

        /// SaveArticleDraft.AsInvalidInputError
        ///
        /// Parent Type: `InvalidInputError`
        public struct AsInvalidInputError: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = SaveArticleDraftMutation.Data.SaveArticleDraft
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.InvalidInputError }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("inputPath", String.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            SaveArticleDraftMutation.Data.SaveArticleDraft.self,
            SaveArticleDraftMutation.Data.SaveArticleDraft.AsInvalidInputError.self
          ] }

          public var inputPath: String { __data["inputPath"] }
        }

        /// SaveArticleDraft.AsNotAuthenticatedError
        ///
        /// Parent Type: `NotAuthenticatedError`
        public struct AsNotAuthenticatedError: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = SaveArticleDraftMutation.Data.SaveArticleDraft
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.NotAuthenticatedError }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("notAuthenticated", String.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            SaveArticleDraftMutation.Data.SaveArticleDraft.self,
            SaveArticleDraftMutation.Data.SaveArticleDraft.AsNotAuthenticatedError.self
          ] }

          public var notAuthenticated: String { __data["notAuthenticated"] }
        }
      }
    }
  }

}