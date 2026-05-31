// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI
@_spi(Execution) @_spi(Unsafe) import ApolloAPI

public extension HackersPub {
  struct GetPasskeyAuthenticationOptionsMutation: GraphQLMutation {
    public static let operationName: String = "GetPasskeyAuthenticationOptionsMutation"
    public static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"mutation GetPasskeyAuthenticationOptionsMutation($sessionId: UUID!) { getPasskeyAuthenticationOptions(sessionId: $sessionId) }"#
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
        .field("getPasskeyAuthenticationOptions", HackersPub.JSON.self, arguments: ["sessionId": .variable("sessionId")]),
      ] }
      @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
        GetPasskeyAuthenticationOptionsMutation.Data.self
      ] }

      /// Generate WebAuthn authentication options for passkey sign-in. Pass a fresh client-generated UUID as `sessionId`; this same `sessionId` must be passed back to `loginByPasskey`.
      public var getPasskeyAuthenticationOptions: HackersPub.JSON { __data["getPasskeyAuthenticationOptions"] }
    }
  }

}