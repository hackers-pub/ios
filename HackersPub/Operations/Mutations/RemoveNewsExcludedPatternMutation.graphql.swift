// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI
@_spi(Execution) @_spi(Unsafe) import ApolloAPI

public extension HackersPub {
  struct RemoveNewsExcludedPatternMutation: GraphQLMutation {
    public static let operationName: String = "RemoveNewsExcludedPatternMutation"
    public static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"mutation RemoveNewsExcludedPatternMutation($id: UUID!) { removeNewsExcludedPattern(id: $id) { __typename ... on RemoveNewsExcludedPatternPayload { removedId } ... on NotAuthenticatedError { notAuthenticated } ... on NotAuthorizedError { notAuthorized } } }"#
      ))

    public var id: UUID

    public init(id: UUID) {
      self.id = id
    }

    @_spi(Unsafe) public var __variables: Variables? { ["id": id] }

    public struct Data: HackersPub.SelectionSet {
      @_spi(Unsafe) public let __data: DataDict
      @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

      @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Mutation }
      @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
        .field("removeNewsExcludedPattern", RemoveNewsExcludedPattern.self, arguments: ["id": .variable("id")]),
      ] }
      @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
        RemoveNewsExcludedPatternMutation.Data.self
      ] }

      /// Remove a news feed exclusion pattern by id, un-hiding links it no longer matches.  Requires a moderator account.
      public var removeNewsExcludedPattern: RemoveNewsExcludedPattern { __data["removeNewsExcludedPattern"] }

      /// RemoveNewsExcludedPattern
      ///
      /// Parent Type: `RemoveNewsExcludedPatternResult`
      public struct RemoveNewsExcludedPattern: HackersPub.SelectionSet {
        @_spi(Unsafe) public let __data: DataDict
        @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

        @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Unions.RemoveNewsExcludedPatternResult }
        @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .inlineFragment(AsRemoveNewsExcludedPatternPayload.self),
          .inlineFragment(AsNotAuthenticatedError.self),
          .inlineFragment(AsNotAuthorizedError.self),
        ] }
        @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
          RemoveNewsExcludedPatternMutation.Data.RemoveNewsExcludedPattern.self
        ] }

        public var asRemoveNewsExcludedPatternPayload: AsRemoveNewsExcludedPatternPayload? { _asInlineFragment() }
        public var asNotAuthenticatedError: AsNotAuthenticatedError? { _asInlineFragment() }
        public var asNotAuthorizedError: AsNotAuthorizedError? { _asInlineFragment() }

        /// RemoveNewsExcludedPattern.AsRemoveNewsExcludedPatternPayload
        ///
        /// Parent Type: `RemoveNewsExcludedPatternPayload`
        public struct AsRemoveNewsExcludedPatternPayload: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = RemoveNewsExcludedPatternMutation.Data.RemoveNewsExcludedPattern
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.RemoveNewsExcludedPatternPayload }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("removedId", HackersPub.UUID?.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            RemoveNewsExcludedPatternMutation.Data.RemoveNewsExcludedPattern.self,
            RemoveNewsExcludedPatternMutation.Data.RemoveNewsExcludedPattern.AsRemoveNewsExcludedPatternPayload.self
          ] }

          /// The removed pattern's id, or `null` if no pattern had that id.
          public var removedId: HackersPub.UUID? { __data["removedId"] }
        }

        /// RemoveNewsExcludedPattern.AsNotAuthenticatedError
        ///
        /// Parent Type: `NotAuthenticatedError`
        public struct AsNotAuthenticatedError: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = RemoveNewsExcludedPatternMutation.Data.RemoveNewsExcludedPattern
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.NotAuthenticatedError }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("notAuthenticated", String.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            RemoveNewsExcludedPatternMutation.Data.RemoveNewsExcludedPattern.self,
            RemoveNewsExcludedPatternMutation.Data.RemoveNewsExcludedPattern.AsNotAuthenticatedError.self
          ] }

          public var notAuthenticated: String { __data["notAuthenticated"] }
        }

        /// RemoveNewsExcludedPattern.AsNotAuthorizedError
        ///
        /// Parent Type: `NotAuthorizedError`
        public struct AsNotAuthorizedError: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = RemoveNewsExcludedPatternMutation.Data.RemoveNewsExcludedPattern
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.NotAuthorizedError }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("notAuthorized", String.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            RemoveNewsExcludedPatternMutation.Data.RemoveNewsExcludedPattern.self,
            RemoveNewsExcludedPatternMutation.Data.RemoveNewsExcludedPattern.AsNotAuthorizedError.self
          ] }

          public var notAuthorized: String { __data["notAuthorized"] }
        }
      }
    }
  }

}