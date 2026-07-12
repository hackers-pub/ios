// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI
@_spi(Execution) @_spi(Unsafe) import ApolloAPI

public extension HackersPub {
  struct AttachArticleSourceMediumMutation: GraphQLMutation {
    public static let operationName: String = "AttachArticleSourceMediumMutation"
    public static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"mutation AttachArticleSourceMediumMutation($articleSourceId: UUID!, $mediumId: UUID!, $key: String) { attachArticleSourceMedium( input: { articleSourceId: $articleSourceId, mediumId: $mediumId, key: $key } ) { __typename ... on AttachArticleSourceMediumPayload { key } ... on InvalidInputError { inputPath } ... on NotAuthenticatedError { notAuthenticated } ... on NotAuthorizedError { notAuthorized } } }"#
      ))

    public var articleSourceId: UUID
    public var mediumId: UUID
    public var key: GraphQLNullable<String>

    public init(
      articleSourceId: UUID,
      mediumId: UUID,
      key: GraphQLNullable<String>
    ) {
      self.articleSourceId = articleSourceId
      self.mediumId = mediumId
      self.key = key
    }

    @_spi(Unsafe) public var __variables: Variables? { [
      "articleSourceId": articleSourceId,
      "mediumId": mediumId,
      "key": key
    ] }

    public struct Data: HackersPub.SelectionSet {
      @_spi(Unsafe) public let __data: DataDict
      @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

      @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Mutation }
      @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
        .field("attachArticleSourceMedium", AttachArticleSourceMedium.self, arguments: ["input": [
          "articleSourceId": .variable("articleSourceId"),
          "mediumId": .variable("mediumId"),
          "key": .variable("key")
        ]]),
      ] }
      @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
        AttachArticleSourceMediumMutation.Data.self
      ] }

      public var attachArticleSourceMedium: AttachArticleSourceMedium { __data["attachArticleSourceMedium"] }

      /// AttachArticleSourceMedium
      ///
      /// Parent Type: `AttachArticleSourceMediumResult`
      public struct AttachArticleSourceMedium: HackersPub.SelectionSet {
        @_spi(Unsafe) public let __data: DataDict
        @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

        @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Unions.AttachArticleSourceMediumResult }
        @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .inlineFragment(AsAttachArticleSourceMediumPayload.self),
          .inlineFragment(AsInvalidInputError.self),
          .inlineFragment(AsNotAuthenticatedError.self),
          .inlineFragment(AsNotAuthorizedError.self),
        ] }
        @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
          AttachArticleSourceMediumMutation.Data.AttachArticleSourceMedium.self
        ] }

        public var asAttachArticleSourceMediumPayload: AsAttachArticleSourceMediumPayload? { _asInlineFragment() }
        public var asInvalidInputError: AsInvalidInputError? { _asInlineFragment() }
        public var asNotAuthenticatedError: AsNotAuthenticatedError? { _asInlineFragment() }
        public var asNotAuthorizedError: AsNotAuthorizedError? { _asInlineFragment() }

        /// AttachArticleSourceMedium.AsAttachArticleSourceMediumPayload
        ///
        /// Parent Type: `AttachArticleSourceMediumPayload`
        public struct AsAttachArticleSourceMediumPayload: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = AttachArticleSourceMediumMutation.Data.AttachArticleSourceMedium
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.AttachArticleSourceMediumPayload }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("key", String.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            AttachArticleSourceMediumMutation.Data.AttachArticleSourceMedium.self,
            AttachArticleSourceMediumMutation.Data.AttachArticleSourceMedium.AsAttachArticleSourceMediumPayload.self
          ] }

          /// The key the medium was attached under. Reference it in the article's Markdown as `hp-medium:KEY`. Equals the requested `key` input when provided, otherwise the medium's UUID.
          public var key: String { __data["key"] }
        }

        /// AttachArticleSourceMedium.AsInvalidInputError
        ///
        /// Parent Type: `InvalidInputError`
        public struct AsInvalidInputError: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = AttachArticleSourceMediumMutation.Data.AttachArticleSourceMedium
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.InvalidInputError }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("inputPath", String.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            AttachArticleSourceMediumMutation.Data.AttachArticleSourceMedium.self,
            AttachArticleSourceMediumMutation.Data.AttachArticleSourceMedium.AsInvalidInputError.self
          ] }

          public var inputPath: String { __data["inputPath"] }
        }

        /// AttachArticleSourceMedium.AsNotAuthenticatedError
        ///
        /// Parent Type: `NotAuthenticatedError`
        public struct AsNotAuthenticatedError: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = AttachArticleSourceMediumMutation.Data.AttachArticleSourceMedium
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.NotAuthenticatedError }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("notAuthenticated", String.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            AttachArticleSourceMediumMutation.Data.AttachArticleSourceMedium.self,
            AttachArticleSourceMediumMutation.Data.AttachArticleSourceMedium.AsNotAuthenticatedError.self
          ] }

          public var notAuthenticated: String { __data["notAuthenticated"] }
        }

        /// AttachArticleSourceMedium.AsNotAuthorizedError
        ///
        /// Parent Type: `NotAuthorizedError`
        public struct AsNotAuthorizedError: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = AttachArticleSourceMediumMutation.Data.AttachArticleSourceMedium
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.NotAuthorizedError }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("notAuthorized", String.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            AttachArticleSourceMediumMutation.Data.AttachArticleSourceMedium.self,
            AttachArticleSourceMediumMutation.Data.AttachArticleSourceMedium.AsNotAuthorizedError.self
          ] }

          public var notAuthorized: String { __data["notAuthorized"] }
        }
      }
    }
  }

}