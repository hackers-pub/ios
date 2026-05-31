// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI
@_spi(Execution) @_spi(Unsafe) import ApolloAPI

public extension HackersPub {
  struct AddNewsExcludedPatternMutation: GraphQLMutation {
    public static let operationName: String = "AddNewsExcludedPatternMutation"
    public static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"mutation AddNewsExcludedPatternMutation($pattern: String!, $note: String) { addNewsExcludedPattern(pattern: $pattern, note: $note) { __typename ... on NewsExcludedPattern { id pattern note created } ... on InvalidInputError { inputPath } ... on NotAuthenticatedError { notAuthenticated } ... on NotAuthorizedError { notAuthorized } } }"#
      ))

    public var pattern: String
    public var note: GraphQLNullable<String>

    public init(
      pattern: String,
      note: GraphQLNullable<String>
    ) {
      self.pattern = pattern
      self.note = note
    }

    @_spi(Unsafe) public var __variables: Variables? { [
      "pattern": pattern,
      "note": note
    ] }

    public struct Data: HackersPub.SelectionSet {
      @_spi(Unsafe) public let __data: DataDict
      @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

      @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Mutation }
      @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
        .field("addNewsExcludedPattern", AddNewsExcludedPattern.self, arguments: [
          "pattern": .variable("pattern"),
          "note": .variable("note")
        ]),
      ] }
      @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
        AddNewsExcludedPatternMutation.Data.self
      ] }

      /// Add a news feed exclusion pattern (a `URLPattern` string) and hide matching links from the feed list.  Idempotent on the pattern string.  Requires a moderator account.  An invalid pattern raises `InvalidInputError`.
      public var addNewsExcludedPattern: AddNewsExcludedPattern { __data["addNewsExcludedPattern"] }

      /// AddNewsExcludedPattern
      ///
      /// Parent Type: `AddNewsExcludedPatternResult`
      public struct AddNewsExcludedPattern: HackersPub.SelectionSet {
        @_spi(Unsafe) public let __data: DataDict
        @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

        @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Unions.AddNewsExcludedPatternResult }
        @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .inlineFragment(AsNewsExcludedPattern.self),
          .inlineFragment(AsInvalidInputError.self),
          .inlineFragment(AsNotAuthenticatedError.self),
          .inlineFragment(AsNotAuthorizedError.self),
        ] }
        @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
          AddNewsExcludedPatternMutation.Data.AddNewsExcludedPattern.self
        ] }

        public var asNewsExcludedPattern: AsNewsExcludedPattern? { _asInlineFragment() }
        public var asInvalidInputError: AsInvalidInputError? { _asInlineFragment() }
        public var asNotAuthenticatedError: AsNotAuthenticatedError? { _asInlineFragment() }
        public var asNotAuthorizedError: AsNotAuthorizedError? { _asInlineFragment() }

        /// AddNewsExcludedPattern.AsNewsExcludedPattern
        ///
        /// Parent Type: `NewsExcludedPattern`
        public struct AsNewsExcludedPattern: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = AddNewsExcludedPatternMutation.Data.AddNewsExcludedPattern
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.NewsExcludedPattern }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("id", HackersPub.UUID.self),
            .field("pattern", String.self),
            .field("note", String?.self),
            .field("created", HackersPub.DateTime.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            AddNewsExcludedPatternMutation.Data.AddNewsExcludedPattern.self,
            AddNewsExcludedPatternMutation.Data.AddNewsExcludedPattern.AsNewsExcludedPattern.self
          ] }

          /// The pattern's row UUID.
          public var id: HackersPub.UUID { __data["id"] }
          /// The `URLPattern` string, e.g. `https://example.com/*` or `https://*.example.com/*`.
          public var pattern: String { __data["pattern"] }
          /// An optional moderator note explaining the exclusion.
          public var note: String? { __data["note"] }
          /// When the pattern was added.
          public var created: HackersPub.DateTime { __data["created"] }
        }

        /// AddNewsExcludedPattern.AsInvalidInputError
        ///
        /// Parent Type: `InvalidInputError`
        public struct AsInvalidInputError: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = AddNewsExcludedPatternMutation.Data.AddNewsExcludedPattern
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.InvalidInputError }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("inputPath", String.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            AddNewsExcludedPatternMutation.Data.AddNewsExcludedPattern.self,
            AddNewsExcludedPatternMutation.Data.AddNewsExcludedPattern.AsInvalidInputError.self
          ] }

          public var inputPath: String { __data["inputPath"] }
        }

        /// AddNewsExcludedPattern.AsNotAuthenticatedError
        ///
        /// Parent Type: `NotAuthenticatedError`
        public struct AsNotAuthenticatedError: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = AddNewsExcludedPatternMutation.Data.AddNewsExcludedPattern
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.NotAuthenticatedError }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("notAuthenticated", String.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            AddNewsExcludedPatternMutation.Data.AddNewsExcludedPattern.self,
            AddNewsExcludedPatternMutation.Data.AddNewsExcludedPattern.AsNotAuthenticatedError.self
          ] }

          public var notAuthenticated: String { __data["notAuthenticated"] }
        }

        /// AddNewsExcludedPattern.AsNotAuthorizedError
        ///
        /// Parent Type: `NotAuthorizedError`
        public struct AsNotAuthorizedError: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = AddNewsExcludedPatternMutation.Data.AddNewsExcludedPattern
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.NotAuthorizedError }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("notAuthorized", String.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            AddNewsExcludedPatternMutation.Data.AddNewsExcludedPattern.self,
            AddNewsExcludedPatternMutation.Data.AddNewsExcludedPattern.AsNotAuthorizedError.self
          ] }

          public var notAuthorized: String { __data["notAuthorized"] }
        }
      }
    }
  }

}