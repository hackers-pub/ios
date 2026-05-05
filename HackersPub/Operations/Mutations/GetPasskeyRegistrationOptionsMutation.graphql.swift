// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI
@_spi(Execution) @_spi(Unsafe) import ApolloAPI

public extension HackersPub {
  struct GetPasskeyRegistrationOptionsMutation: GraphQLMutation {
    public static let operationName: String = "GetPasskeyRegistrationOptionsMutation"
    public static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"mutation GetPasskeyRegistrationOptionsMutation($accountId: ID!) { getPasskeyRegistrationOptions(accountId: $accountId) }"#
      ))

    public var accountId: ID

    public init(accountId: ID) {
      self.accountId = accountId
    }

    @_spi(Unsafe) public var __variables: Variables? { ["accountId": accountId] }

    public struct Data: HackersPub.SelectionSet {
      @_spi(Unsafe) public let __data: DataDict
      @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

      @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Mutation }
      @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
        .field("getPasskeyRegistrationOptions", HackersPub.JSON.self, arguments: ["accountId": .variable("accountId")]),
      ] }
      @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
        GetPasskeyRegistrationOptionsMutation.Data.self
      ] }

      public var getPasskeyRegistrationOptions: HackersPub.JSON { __data["getPasskeyRegistrationOptions"] }
    }
  }

}