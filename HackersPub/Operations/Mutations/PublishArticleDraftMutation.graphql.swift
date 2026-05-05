// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI
@_spi(Execution) @_spi(Unsafe) import ApolloAPI

public extension HackersPub {
  struct PublishArticleDraftMutation: GraphQLMutation {
    public static let operationName: String = "PublishArticleDraftMutation"
    public static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"mutation PublishArticleDraftMutation($id: ID!, $slug: String!, $language: Locale!, $allowLlmTranslation: Boolean) { publishArticleDraft( input: { id: $id slug: $slug language: $language allowLlmTranslation: $allowLlmTranslation } ) { __typename ... on PublishArticleDraftPayload { article { __typename id name url } deletedDraftId } ... on InvalidInputError { inputPath } ... on NotAuthenticatedError { notAuthenticated } } }"#
      ))

    public var id: ID
    public var slug: String
    public var language: Locale
    public var allowLlmTranslation: GraphQLNullable<Bool>

    public init(
      id: ID,
      slug: String,
      language: Locale,
      allowLlmTranslation: GraphQLNullable<Bool>
    ) {
      self.id = id
      self.slug = slug
      self.language = language
      self.allowLlmTranslation = allowLlmTranslation
    }

    @_spi(Unsafe) public var __variables: Variables? { [
      "id": id,
      "slug": slug,
      "language": language,
      "allowLlmTranslation": allowLlmTranslation
    ] }

    public struct Data: HackersPub.SelectionSet {
      @_spi(Unsafe) public let __data: DataDict
      @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

      @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Mutation }
      @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
        .field("publishArticleDraft", PublishArticleDraft.self, arguments: ["input": [
          "id": .variable("id"),
          "slug": .variable("slug"),
          "language": .variable("language"),
          "allowLlmTranslation": .variable("allowLlmTranslation")
        ]]),
      ] }
      @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
        PublishArticleDraftMutation.Data.self
      ] }

      public var publishArticleDraft: PublishArticleDraft { __data["publishArticleDraft"] }

      /// PublishArticleDraft
      ///
      /// Parent Type: `PublishArticleDraftResult`
      public struct PublishArticleDraft: HackersPub.SelectionSet {
        @_spi(Unsafe) public let __data: DataDict
        @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

        @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Unions.PublishArticleDraftResult }
        @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .inlineFragment(AsPublishArticleDraftPayload.self),
          .inlineFragment(AsInvalidInputError.self),
          .inlineFragment(AsNotAuthenticatedError.self),
        ] }
        @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
          PublishArticleDraftMutation.Data.PublishArticleDraft.self
        ] }

        public var asPublishArticleDraftPayload: AsPublishArticleDraftPayload? { _asInlineFragment() }
        public var asInvalidInputError: AsInvalidInputError? { _asInlineFragment() }
        public var asNotAuthenticatedError: AsNotAuthenticatedError? { _asInlineFragment() }

        /// PublishArticleDraft.AsPublishArticleDraftPayload
        ///
        /// Parent Type: `PublishArticleDraftPayload`
        public struct AsPublishArticleDraftPayload: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = PublishArticleDraftMutation.Data.PublishArticleDraft
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.PublishArticleDraftPayload }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("article", Article.self),
            .field("deletedDraftId", HackersPub.ID.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            PublishArticleDraftMutation.Data.PublishArticleDraft.self,
            PublishArticleDraftMutation.Data.PublishArticleDraft.AsPublishArticleDraftPayload.self
          ] }

          public var article: Article { __data["article"] }
          public var deletedDraftId: HackersPub.ID { __data["deletedDraftId"] }

          /// PublishArticleDraft.AsPublishArticleDraftPayload.Article
          ///
          /// Parent Type: `Article`
          public struct Article: HackersPub.SelectionSet {
            @_spi(Unsafe) public let __data: DataDict
            @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

            @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Article }
            @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
              .field("__typename", String.self),
              .field("id", HackersPub.ID.self),
              .field("name", String?.self),
              .field("url", HackersPub.URL?.self),
            ] }
            @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
              PublishArticleDraftMutation.Data.PublishArticleDraft.AsPublishArticleDraftPayload.Article.self
            ] }

            public var id: HackersPub.ID { __data["id"] }
            public var name: String? { __data["name"] }
            public var url: HackersPub.URL? { __data["url"] }
          }
        }

        /// PublishArticleDraft.AsInvalidInputError
        ///
        /// Parent Type: `InvalidInputError`
        public struct AsInvalidInputError: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = PublishArticleDraftMutation.Data.PublishArticleDraft
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.InvalidInputError }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("inputPath", String.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            PublishArticleDraftMutation.Data.PublishArticleDraft.self,
            PublishArticleDraftMutation.Data.PublishArticleDraft.AsInvalidInputError.self
          ] }

          public var inputPath: String { __data["inputPath"] }
        }

        /// PublishArticleDraft.AsNotAuthenticatedError
        ///
        /// Parent Type: `NotAuthenticatedError`
        public struct AsNotAuthenticatedError: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = PublishArticleDraftMutation.Data.PublishArticleDraft
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.NotAuthenticatedError }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("notAuthenticated", String.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            PublishArticleDraftMutation.Data.PublishArticleDraft.self,
            PublishArticleDraftMutation.Data.PublishArticleDraft.AsNotAuthenticatedError.self
          ] }

          public var notAuthenticated: String { __data["notAuthenticated"] }
        }
      }
    }
  }

}