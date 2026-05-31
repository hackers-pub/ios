// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI
@_spi(Execution) @_spi(Unsafe) import ApolloAPI

public extension HackersPub {
  struct ArticleTranslationQuery: GraphQLQuery {
    public static let operationName: String = "ArticleTranslationQuery"
    public static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"query ArticleTranslationQuery($id: ID!, $language: Locale!) { node(id: $id) { __typename ... on Article { id contents(includeBeingTranslated: true, language: $language) { __typename id language title content summary toc beingTranslated url } } } }"#
      ))

    public var id: ID
    public var language: Locale

    public init(
      id: ID,
      language: Locale
    ) {
      self.id = id
      self.language = language
    }

    @_spi(Unsafe) public var __variables: Variables? { [
      "id": id,
      "language": language
    ] }

    public struct Data: HackersPub.SelectionSet {
      @_spi(Unsafe) public let __data: DataDict
      @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

      @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Query }
      @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
        .field("node", Node?.self, arguments: ["id": .variable("id")]),
      ] }
      @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
        ArticleTranslationQuery.Data.self
      ] }

      public var node: Node? { __data["node"] }

      /// Node
      ///
      /// Parent Type: `Node`
      public struct Node: HackersPub.SelectionSet {
        @_spi(Unsafe) public let __data: DataDict
        @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

        @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Interfaces.Node }
        @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .inlineFragment(AsArticle.self),
        ] }
        @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
          ArticleTranslationQuery.Data.Node.self
        ] }

        public var asArticle: AsArticle? { _asInlineFragment() }

        /// Node.AsArticle
        ///
        /// Parent Type: `Article`
        public struct AsArticle: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = ArticleTranslationQuery.Data.Node
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Article }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("id", HackersPub.ID.self),
            .field("contents", [Content].self, arguments: [
              "includeBeingTranslated": true,
              "language": .variable("language")
            ]),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            ArticleTranslationQuery.Data.Node.self,
            ArticleTranslationQuery.Data.Node.AsArticle.self
          ] }

          public var id: HackersPub.ID { __data["id"] }
          /// All available language versions of this article's content. Pass `language` to get only the best-matching locale (BCP 47 negotiation). Pass `includeBeingTranslated: true` to also include language versions whose LLM translation is still in progress.
          public var contents: [Content] { __data["contents"] }

          /// Node.AsArticle.Content
          ///
          /// Parent Type: `ArticleContent`
          public struct Content: HackersPub.SelectionSet {
            @_spi(Unsafe) public let __data: DataDict
            @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

            @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.ArticleContent }
            @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
              .field("__typename", String.self),
              .field("id", HackersPub.ID.self),
              .field("language", HackersPub.Locale.self),
              .field("title", String.self),
              .field("content", HackersPub.HTML.self),
              .field("summary", String?.self),
              .field("toc", HackersPub.JSON.self),
              .field("beingTranslated", Bool.self),
              .field("url", HackersPub.URL.self),
            ] }
            @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
              ArticleTranslationQuery.Data.Node.AsArticle.Content.self
            ] }

            public var id: HackersPub.ID { __data["id"] }
            /// BCP 47 language tag identifying this content version.
            public var language: HackersPub.Locale { __data["language"] }
            public var title: String { __data["title"] }
            /// Rendered HTML of this language version, with media URLs resolved and external links annotated.
            public var content: HackersPub.HTML { __data["content"] }
            /// LLM-generated summary for this language version. `null` until generation completes. Check `summaryStarted` to distinguish between "not requested" and "in progress".
            public var summary: String? { __data["summary"] }
            /// Table of contents for the article content.
            public var toc: HackersPub.JSON { __data["toc"] }
            /// Whether an LLM translation into this language is currently in progress. When `true`, the content may be incomplete.
            public var beingTranslated: Bool { __data["beingTranslated"] }
            /// Canonical URL for this language version. For the article's primary language this is `/@username/year/slug`; for other language versions it appends `/{language}` to that path.
            public var url: HackersPub.URL { __data["url"] }
          }
        }
      }
    }
  }

}