// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI
@_spi(Execution) @_spi(Unsafe) import ApolloAPI

public extension HackersPub {
  struct VerifyPasskeyRegistrationMutation: GraphQLMutation {
    public static let operationName: String = "VerifyPasskeyRegistrationMutation"
    public static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"mutation VerifyPasskeyRegistrationMutation($accountId: ID!, $name: String!, $registrationResponse: JSON!) { verifyPasskeyRegistration( accountId: $accountId name: $name registrationResponse: $registrationResponse ) { __typename verified passkey { __typename id name created lastUsed } } }"#
      ))

    public var accountId: ID
    public var name: String
    public var registrationResponse: JSON

    public init(
      accountId: ID,
      name: String,
      registrationResponse: JSON
    ) {
      self.accountId = accountId
      self.name = name
      self.registrationResponse = registrationResponse
    }

    @_spi(Unsafe) public var __variables: Variables? { [
      "accountId": accountId,
      "name": name,
      "registrationResponse": registrationResponse
    ] }

    public struct Data: HackersPub.SelectionSet {
      @_spi(Unsafe) public let __data: DataDict
      @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

      @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Mutation }
      @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
        .field("verifyPasskeyRegistration", VerifyPasskeyRegistration.self, arguments: [
          "accountId": .variable("accountId"),
          "name": .variable("name"),
          "registrationResponse": .variable("registrationResponse")
        ]),
      ] }
      @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
        VerifyPasskeyRegistrationMutation.Data.self
      ] }

      public var verifyPasskeyRegistration: VerifyPasskeyRegistration { __data["verifyPasskeyRegistration"] }

      /// VerifyPasskeyRegistration
      ///
      /// Parent Type: `PasskeyRegistrationResult`
      public struct VerifyPasskeyRegistration: HackersPub.SelectionSet {
        @_spi(Unsafe) public let __data: DataDict
        @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

        @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.PasskeyRegistrationResult }
        @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .field("verified", Bool.self),
          .field("passkey", Passkey?.self),
        ] }
        @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
          VerifyPasskeyRegistrationMutation.Data.VerifyPasskeyRegistration.self
        ] }

        public var verified: Bool { __data["verified"] }
        public var passkey: Passkey? { __data["passkey"] }

        /// VerifyPasskeyRegistration.Passkey
        ///
        /// Parent Type: `Passkey`
        public struct Passkey: HackersPub.SelectionSet {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Passkey }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("__typename", String.self),
            .field("id", HackersPub.ID.self),
            .field("name", String.self),
            .field("created", HackersPub.DateTime.self),
            .field("lastUsed", HackersPub.DateTime?.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            VerifyPasskeyRegistrationMutation.Data.VerifyPasskeyRegistration.Passkey.self
          ] }

          public var id: HackersPub.ID { __data["id"] }
          public var name: String { __data["name"] }
          public var created: HackersPub.DateTime { __data["created"] }
          public var lastUsed: HackersPub.DateTime? { __data["lastUsed"] }
        }
      }
    }
  }

}