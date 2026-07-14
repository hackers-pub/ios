// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI
@_spi(Execution) @_spi(Unsafe) import ApolloAPI

public extension HackersPub {
  struct LoginByPasskeyMutation: GraphQLMutation {
    public static let operationName: String = "LoginByPasskeyMutation"
    public static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"mutation LoginByPasskeyMutation($sessionId: UUID!, $authenticationResponse: JSON!) { loginByPasskey( sessionId: $sessionId authenticationResponse: $authenticationResponse ) { __typename ... on Session { id account { __typename id username name avatarUrl handle } } } }"#
      ))

    public var sessionId: UUID
    public var authenticationResponse: JSON

    public init(
      sessionId: UUID,
      authenticationResponse: JSON
    ) {
      self.sessionId = sessionId
      self.authenticationResponse = authenticationResponse
    }

    @_spi(Unsafe) public var __variables: Variables? { [
      "sessionId": sessionId,
      "authenticationResponse": authenticationResponse
    ] }

    public struct Data: HackersPub.SelectionSet {
      @_spi(Unsafe) public let __data: DataDict
      @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

      @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Mutation }
      @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
        .field("loginByPasskey", LoginByPasskey?.self, arguments: [
          "sessionId": .variable("sessionId"),
          "authenticationResponse": .variable("authenticationResponse")
        ]),
      ] }
      @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
        LoginByPasskeyMutation.Data.self
      ] }

      /// Authenticate using a WebAuthn passkey. First call `getPasskeyAuthenticationOptions` with a fresh `sessionId` UUID, then pass the authenticator's response back here as `authenticationResponse`. Returns `null` when verification fails, and `AccountBannedError` when the passkey is valid but the account is permanently suspended (banned).
      public var loginByPasskey: LoginByPasskey? { __data["loginByPasskey"] }

      /// LoginByPasskey
      ///
      /// Parent Type: `LoginByPasskeyResult`
      public struct LoginByPasskey: HackersPub.SelectionSet {
        @_spi(Unsafe) public let __data: DataDict
        @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

        @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Unions.LoginByPasskeyResult }
        @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .inlineFragment(AsSession.self),
        ] }
        @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
          LoginByPasskeyMutation.Data.LoginByPasskey.self
        ] }

        public var asSession: AsSession? { _asInlineFragment() }

        /// LoginByPasskey.AsSession
        ///
        /// Parent Type: `Session`
        public struct AsSession: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = LoginByPasskeyMutation.Data.LoginByPasskey
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Session }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("id", HackersPub.UUID.self),
            .field("account", Account.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            LoginByPasskeyMutation.Data.LoginByPasskey.self,
            LoginByPasskeyMutation.Data.LoginByPasskey.AsSession.self
          ] }

          /// The access token for the session.
          public var id: HackersPub.UUID { __data["id"] }
          public var account: Account { __data["account"] }

          /// LoginByPasskey.AsSession.Account
          ///
          /// Parent Type: `Account`
          public struct Account: HackersPub.SelectionSet {
            @_spi(Unsafe) public let __data: DataDict
            @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

            @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Account }
            @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
              .field("__typename", String.self),
              .field("id", HackersPub.ID.self),
              .field("username", String.self),
              .field("name", String.self),
              .field("avatarUrl", HackersPub.URL.self),
              .field("handle", String.self),
            ] }
            @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
              LoginByPasskeyMutation.Data.LoginByPasskey.AsSession.Account.self
            ] }

            public var id: HackersPub.ID { __data["id"] }
            public var username: String { __data["username"] }
            /// The account holder's display name.  Empty when the account is permanently suspended (banned) and the viewer is neither the account holder nor a moderator (mirrors the redacted `Actor`).
            public var name: String { __data["name"] }
            @available(*, deprecated, message: "Use avatarMediumId instead.")
            public var avatarUrl: HackersPub.URL { __data["avatarUrl"] }
            /// Full fediverse handle including the instance host, e.g., @alice@hackers.pub. Suitable for display and for cross-instance @-mention targeting.
            public var handle: String { __data["handle"] }
          }
        }
      }
    }
  }

}