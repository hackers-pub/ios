// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI
@_spi(Execution) @_spi(Unsafe) import ApolloAPI

public extension HackersPub {
  struct RevokeSessionMutation: GraphQLMutation {
    public static let operationName: String = "RevokeSessionMutation"
    public static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"mutation RevokeSessionMutation($sessionId: UUID!) { revokeSession(sessionId: $sessionId) { __typename id } }"#
      ))

    public var sessionId: UUID

    public init(sessionId: UUID) {
      self.sessionId = sessionId
    }

    @_spi(Unsafe) public var __variables: Variables? { ["sessionId": sessionId] }

    public struct Data: HackersPub.SelectionSet {
      @_spi(Unsafe) public let __data: DataDict
      @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

      @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Mutation }
      @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
        .field("revokeSession", RevokeSession?.self, arguments: ["sessionId": .variable("sessionId")]),
      ] }
      @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
        RevokeSessionMutation.Data.self
      ] }

      /// Revoke a session by its ID.
      public var revokeSession: RevokeSession? { __data["revokeSession"] }

      /// RevokeSession
      ///
      /// Parent Type: `Session`
      public struct RevokeSession: HackersPub.SelectionSet {
        @_spi(Unsafe) public let __data: DataDict
        @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

        @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Session }
        @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .field("id", HackersPub.UUID.self),
        ] }
        @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
          RevokeSessionMutation.Data.RevokeSession.self
        ] }

        /// The access token for the session.
        public var id: HackersPub.UUID { __data["id"] }
      }
    }
  }

}