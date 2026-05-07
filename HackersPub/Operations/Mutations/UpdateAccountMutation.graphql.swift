// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI
@_spi(Execution) @_spi(Unsafe) import ApolloAPI

public extension HackersPub {
  struct UpdateAccountMutation: GraphQLMutation {
    public static let operationName: String = "UpdateAccountMutation"
    public static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"mutation UpdateAccountMutation($id: ID!, $name: String, $bio: String, $avatarMediumId: UUID, $links: [AccountLinkInput!]) { updateAccount( input: { id: $id name: $name bio: $bio avatarMediumId: $avatarMediumId links: $links } ) { __typename account { __typename id username name bio avatarMediumId avatarUrl handle links { __typename id name url } } } }"#
      ))

    public var id: ID
    public var name: GraphQLNullable<String>
    public var bio: GraphQLNullable<String>
    public var avatarMediumId: GraphQLNullable<UUID>
    public var links: GraphQLNullable<[AccountLinkInput]>

    public init(
      id: ID,
      name: GraphQLNullable<String>,
      bio: GraphQLNullable<String>,
      avatarMediumId: GraphQLNullable<UUID>,
      links: GraphQLNullable<[AccountLinkInput]>
    ) {
      self.id = id
      self.name = name
      self.bio = bio
      self.avatarMediumId = avatarMediumId
      self.links = links
    }

    @_spi(Unsafe) public var __variables: Variables? { [
      "id": id,
      "name": name,
      "bio": bio,
      "avatarMediumId": avatarMediumId,
      "links": links
    ] }

    public struct Data: HackersPub.SelectionSet {
      @_spi(Unsafe) public let __data: DataDict
      @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

      @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Mutation }
      @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
        .field("updateAccount", UpdateAccount.self, arguments: ["input": [
          "id": .variable("id"),
          "name": .variable("name"),
          "bio": .variable("bio"),
          "avatarMediumId": .variable("avatarMediumId"),
          "links": .variable("links")
        ]]),
      ] }
      @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
        UpdateAccountMutation.Data.self
      ] }

      public var updateAccount: UpdateAccount { __data["updateAccount"] }

      /// UpdateAccount
      ///
      /// Parent Type: `UpdateAccountPayload`
      public struct UpdateAccount: HackersPub.SelectionSet {
        @_spi(Unsafe) public let __data: DataDict
        @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

        @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.UpdateAccountPayload }
        @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .field("account", Account.self),
        ] }
        @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
          UpdateAccountMutation.Data.UpdateAccount.self
        ] }

        public var account: Account { __data["account"] }

        /// UpdateAccount.Account
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
            .field("bio", HackersPub.Markdown.self),
            .field("avatarMediumId", HackersPub.UUID?.self),
            .field("avatarUrl", HackersPub.URL.self),
            .field("handle", String.self),
            .field("links", [Link].self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            UpdateAccountMutation.Data.UpdateAccount.Account.self
          ] }

          public var id: HackersPub.ID { __data["id"] }
          public var username: String { __data["username"] }
          public var name: String { __data["name"] }
          public var bio: HackersPub.Markdown { __data["bio"] }
          /// UUID of the medium used as this account's avatar.
          public var avatarMediumId: HackersPub.UUID? { __data["avatarMediumId"] }
          @available(*, deprecated, message: "Use avatarMediumId instead.")
          public var avatarUrl: HackersPub.URL { __data["avatarUrl"] }
          public var handle: String { __data["handle"] }
          public var links: [Link] { __data["links"] }

          /// UpdateAccount.Account.Link
          ///
          /// Parent Type: `AccountLink`
          public struct Link: HackersPub.SelectionSet {
            @_spi(Unsafe) public let __data: DataDict
            @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

            @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.AccountLink }
            @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
              .field("__typename", String.self),
              .field("id", HackersPub.ID.self),
              .field("name", String.self),
              .field("url", HackersPub.URL.self),
            ] }
            @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
              UpdateAccountMutation.Data.UpdateAccount.Account.Link.self
            ] }

            public var id: HackersPub.ID { __data["id"] }
            public var name: String { __data["name"] }
            public var url: HackersPub.URL { __data["url"] }
          }
        }
      }
    }
  }

}