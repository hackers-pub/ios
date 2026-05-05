// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI
@_spi(Execution) @_spi(Unsafe) import ApolloAPI

public extension HackersPub {
  struct UpdateArticleMutation: GraphQLMutation {
    public static let operationName: String = "UpdateArticleMutation"
    public static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"mutation UpdateArticleMutation($articleId: ID!, $title: String!, $content: Markdown!, $tags: [String!]!, $language: Locale!, $allowLlmTranslation: Boolean!) { updateArticle( input: { articleId: $articleId title: $title content: $content tags: $tags language: $language allowLlmTranslation: $allowLlmTranslation } ) { __typename ... on UpdateArticlePayload { article { __typename id name url } } ... on InvalidInputError { inputPath } ... on NotAuthenticatedError { notAuthenticated } } }"#
      ))

    public var articleId: ID
    public var title: String
    public var content: Markdown
    public var tags: [String]
    public var language: Locale
    public var allowLlmTranslation: Bool

    public init(
      articleId: ID,
      title: String,
      content: Markdown,
      tags: [String],
      language: Locale,
      allowLlmTranslation: Bool
    ) {
      self.articleId = articleId
      self.title = title
      self.content = content
      self.tags = tags
      self.language = language
      self.allowLlmTranslation = allowLlmTranslation
    }

    @_spi(Unsafe) public var __variables: Variables? { [
      "articleId": articleId,
      "title": title,
      "content": content,
      "tags": tags,
      "language": language,
      "allowLlmTranslation": allowLlmTranslation
    ] }

    public struct Data: HackersPub.SelectionSet {
      @_spi(Unsafe) public let __data: DataDict
      @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

      @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Mutation }
      @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
        .field("updateArticle", UpdateArticle.self, arguments: ["input": [
          "articleId": .variable("articleId"),
          "title": .variable("title"),
          "content": .variable("content"),
          "tags": .variable("tags"),
          "language": .variable("language"),
          "allowLlmTranslation": .variable("allowLlmTranslation")
        ]]),
      ] }
      @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
        UpdateArticleMutation.Data.self
      ] }

      public var updateArticle: UpdateArticle { __data["updateArticle"] }

      /// UpdateArticle
      ///
      /// Parent Type: `UpdateArticleResult`
      public struct UpdateArticle: HackersPub.SelectionSet {
        @_spi(Unsafe) public let __data: DataDict
        @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

        @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Unions.UpdateArticleResult }
        @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .inlineFragment(AsUpdateArticlePayload.self),
          .inlineFragment(AsInvalidInputError.self),
          .inlineFragment(AsNotAuthenticatedError.self),
        ] }
        @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
          UpdateArticleMutation.Data.UpdateArticle.self
        ] }

        public var asUpdateArticlePayload: AsUpdateArticlePayload? { _asInlineFragment() }
        public var asInvalidInputError: AsInvalidInputError? { _asInlineFragment() }
        public var asNotAuthenticatedError: AsNotAuthenticatedError? { _asInlineFragment() }

        /// UpdateArticle.AsUpdateArticlePayload
        ///
        /// Parent Type: `UpdateArticlePayload`
        public struct AsUpdateArticlePayload: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = UpdateArticleMutation.Data.UpdateArticle
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.UpdateArticlePayload }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("article", Article.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            UpdateArticleMutation.Data.UpdateArticle.self,
            UpdateArticleMutation.Data.UpdateArticle.AsUpdateArticlePayload.self
          ] }

          public var article: Article { __data["article"] }

          /// UpdateArticle.AsUpdateArticlePayload.Article
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
              UpdateArticleMutation.Data.UpdateArticle.AsUpdateArticlePayload.Article.self
            ] }

            public var id: HackersPub.ID { __data["id"] }
            public var name: String? { __data["name"] }
            public var url: HackersPub.URL? { __data["url"] }
          }
        }

        /// UpdateArticle.AsInvalidInputError
        ///
        /// Parent Type: `InvalidInputError`
        public struct AsInvalidInputError: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = UpdateArticleMutation.Data.UpdateArticle
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.InvalidInputError }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("inputPath", String.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            UpdateArticleMutation.Data.UpdateArticle.self,
            UpdateArticleMutation.Data.UpdateArticle.AsInvalidInputError.self
          ] }

          public var inputPath: String { __data["inputPath"] }
        }

        /// UpdateArticle.AsNotAuthenticatedError
        ///
        /// Parent Type: `NotAuthenticatedError`
        public struct AsNotAuthenticatedError: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = UpdateArticleMutation.Data.UpdateArticle
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.NotAuthenticatedError }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("notAuthenticated", String.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            UpdateArticleMutation.Data.UpdateArticle.self,
            UpdateArticleMutation.Data.UpdateArticle.AsNotAuthenticatedError.self
          ] }

          public var notAuthenticated: String { __data["notAuthenticated"] }
        }
      }
    }
  }

}