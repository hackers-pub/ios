// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI
@_spi(Execution) @_spi(Unsafe) import ApolloAPI

public extension HackersPub {
  struct RevokePasskeyMutation: GraphQLMutation {
    public static let operationName: String = "RevokePasskeyMutation"
    public static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"mutation RevokePasskeyMutation($passkeyId: ID!) { revokePasskey(passkeyId: $passkeyId) }"#
      ))

    public var passkeyId: ID

    public init(passkeyId: ID) {
      self.passkeyId = passkeyId
    }

    @_spi(Unsafe) public var __variables: Variables? { ["passkeyId": passkeyId] }

    public struct Data: HackersPub.SelectionSet {
      @_spi(Unsafe) public let __data: DataDict
      @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

      @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Mutation }
      @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
        .field("revokePasskey", HackersPub.ID?.self, arguments: ["passkeyId": .variable("passkeyId")]),
      ] }
      @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
        RevokePasskeyMutation.Data.self
      ] }

      public var revokePasskey: HackersPub.ID? { __data["revokePasskey"] }
    }
  }

}