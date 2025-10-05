// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI
@_spi(Execution) @_spi(Unsafe) import ApolloAPI

public extension HackersPub {
  struct LoginByUsernameMutation: GraphQLMutation {
    public static let operationName: String = "LoginByUsernameMutation"
    public static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"mutation LoginByUsernameMutation($username: String!, $locale: Locale!, $verifyUrl: URITemplate!) { loginByUsername(username: $username, locale: $locale, verifyUrl: $verifyUrl) { __typename ... on LoginChallenge { token } ... on AccountNotFoundError { query } } }"#
      ))

    public var username: String
    public var locale: Locale
    public var verifyUrl: URITemplate

    public init(
      username: String,
      locale: Locale,
      verifyUrl: URITemplate
    ) {
      self.username = username
      self.locale = locale
      self.verifyUrl = verifyUrl
    }

    @_spi(Unsafe) public var __variables: Variables? { [
      "username": username,
      "locale": locale,
      "verifyUrl": verifyUrl
    ] }

    public struct Data: HackersPub.SelectionSet {
      @_spi(Unsafe) public let __data: DataDict
      @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

      @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Mutation }
      @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
        .field("loginByUsername", LoginByUsername.self, arguments: [
          "username": .variable("username"),
          "locale": .variable("locale"),
          "verifyUrl": .variable("verifyUrl")
        ]),
      ] }
      @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
        LoginByUsernameMutation.Data.self
      ] }

      public var loginByUsername: LoginByUsername { __data["loginByUsername"] }

      /// LoginByUsername
      ///
      /// Parent Type: `LoginResult`
      public struct LoginByUsername: HackersPub.SelectionSet {
        @_spi(Unsafe) public let __data: DataDict
        @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

        @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Unions.LoginResult }
        @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .inlineFragment(AsLoginChallenge.self),
          .inlineFragment(AsAccountNotFoundError.self),
        ] }
        @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
          LoginByUsernameMutation.Data.LoginByUsername.self
        ] }

        public var asLoginChallenge: AsLoginChallenge? { _asInlineFragment() }
        public var asAccountNotFoundError: AsAccountNotFoundError? { _asInlineFragment() }

        /// LoginByUsername.AsLoginChallenge
        ///
        /// Parent Type: `LoginChallenge`
        public struct AsLoginChallenge: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = LoginByUsernameMutation.Data.LoginByUsername
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.LoginChallenge }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("token", HackersPub.UUID.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            LoginByUsernameMutation.Data.LoginByUsername.self,
            LoginByUsernameMutation.Data.LoginByUsername.AsLoginChallenge.self
          ] }

          public var token: HackersPub.UUID { __data["token"] }
        }

        /// LoginByUsername.AsAccountNotFoundError
        ///
        /// Parent Type: `AccountNotFoundError`
        public struct AsAccountNotFoundError: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = LoginByUsernameMutation.Data.LoginByUsername
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.AccountNotFoundError }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("query", String.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            LoginByUsernameMutation.Data.LoginByUsername.self,
            LoginByUsernameMutation.Data.LoginByUsername.AsAccountNotFoundError.self
          ] }

          public var query: String { __data["query"] }
        }
      }
    }
  }

}