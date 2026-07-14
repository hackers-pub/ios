// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI
@_spi(Execution) @_spi(Unsafe) import ApolloAPI

public extension HackersPub {
  struct CompleteLoginChallengeMutation: GraphQLMutation {
    public static let operationName: String = "CompleteLoginChallengeMutation"
    public static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"mutation CompleteLoginChallengeMutation($token: UUID!, $code: String!) { completeLoginChallenge(token: $token, code: $code) { __typename ... on Session { id account { __typename id username name avatarUrl handle } } } }"#
      ))

    public var token: UUID
    public var code: String

    public init(
      token: UUID,
      code: String
    ) {
      self.token = token
      self.code = code
    }

    @_spi(Unsafe) public var __variables: Variables? { [
      "token": token,
      "code": code
    ] }

    public struct Data: HackersPub.SelectionSet {
      @_spi(Unsafe) public let __data: DataDict
      @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

      @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Mutation }
      @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
        .field("completeLoginChallenge", CompleteLoginChallenge?.self, arguments: [
          "token": .variable("token"),
          "code": .variable("code")
        ]),
      ] }
      @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
        CompleteLoginChallengeMutation.Data.self
      ] }

      /// Exchange the `(token, code)` pair from a magic link email for a session. Returns `null` when the challenge does not exist or the code does not match, and `AccountBannedError` when the credential is valid but the account is permanently suspended (banned). The returned `Session.id` is the bearer token to include in the `Authorization` header for subsequent authenticated requests.
      public var completeLoginChallenge: CompleteLoginChallenge? { __data["completeLoginChallenge"] }

      /// CompleteLoginChallenge
      ///
      /// Parent Type: `CompleteLoginChallengeResult`
      public struct CompleteLoginChallenge: HackersPub.SelectionSet {
        @_spi(Unsafe) public let __data: DataDict
        @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

        @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Unions.CompleteLoginChallengeResult }
        @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .inlineFragment(AsSession.self),
        ] }
        @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
          CompleteLoginChallengeMutation.Data.CompleteLoginChallenge.self
        ] }

        public var asSession: AsSession? { _asInlineFragment() }

        /// CompleteLoginChallenge.AsSession
        ///
        /// Parent Type: `Session`
        public struct AsSession: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = CompleteLoginChallengeMutation.Data.CompleteLoginChallenge
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Session }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("id", HackersPub.UUID.self),
            .field("account", Account.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            CompleteLoginChallengeMutation.Data.CompleteLoginChallenge.self,
            CompleteLoginChallengeMutation.Data.CompleteLoginChallenge.AsSession.self
          ] }

          /// The access token for the session.
          public var id: HackersPub.UUID { __data["id"] }
          public var account: Account { __data["account"] }

          /// CompleteLoginChallenge.AsSession.Account
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
              CompleteLoginChallengeMutation.Data.CompleteLoginChallenge.AsSession.Account.self
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