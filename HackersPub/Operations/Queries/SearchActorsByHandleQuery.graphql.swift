// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI
@_spi(Execution) @_spi(Unsafe) import ApolloAPI

public extension HackersPub {
  struct SearchActorsByHandleQuery: GraphQLQuery {
    public static let operationName: String = "SearchActorsByHandleQuery"
    public static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"query SearchActorsByHandleQuery($prefix: String!, $limit: Int = 10) { searchActorsByHandle(prefix: $prefix, limit: $limit) { __typename id handle name avatarUrl } }"#
      ))

    public var prefix: String
    public var limit: GraphQLNullable<Int32>

    public init(
      prefix: String,
      limit: GraphQLNullable<Int32> = 10
    ) {
      self.prefix = prefix
      self.limit = limit
    }

    @_spi(Unsafe) public var __variables: Variables? { [
      "prefix": prefix,
      "limit": limit
    ] }

    public struct Data: HackersPub.SelectionSet {
      @_spi(Unsafe) public let __data: DataDict
      @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

      @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Query }
      @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
        .field("searchActorsByHandle", [SearchActorsByHandle].self, arguments: [
          "prefix": .variable("prefix"),
          "limit": .variable("limit")
        ]),
      ] }
      @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
        SearchActorsByHandleQuery.Data.self
      ] }

      /// Prefix search for @mention autocomplete. Matches against both username and host. Requires authentication to prevent unauthenticated callers from triggering outbound federation lookups. Capped at 50 results.
      public var searchActorsByHandle: [SearchActorsByHandle] { __data["searchActorsByHandle"] }

      /// SearchActorsByHandle
      ///
      /// Parent Type: `Actor`
      public struct SearchActorsByHandle: HackersPub.SelectionSet {
        @_spi(Unsafe) public let __data: DataDict
        @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

        @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Actor }
        @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .field("id", HackersPub.ID.self),
          .field("handle", String.self),
          .field("name", HackersPub.HTML?.self),
          .field("avatarUrl", HackersPub.URL.self),
        ] }
        @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
          SearchActorsByHandleQuery.Data.SearchActorsByHandle.self
        ] }

        public var id: HackersPub.ID { __data["id"] }
        /// Full fediverse handle in `@username@host` format, ready to use in @-mentions across the fediverse.
        public var handle: String { __data["handle"] }
        /// The actor's display name rendered as HTML, with custom emoji shortcodes replaced by inline `<img>` elements. `null` when the actor has no display name set.
        public var name: HackersPub.HTML? { __data["name"] }
        /// URL of the actor's avatar image. Falls back to a Gravatar URL derived from the account's email for local actors without an uploaded avatar.
        public var avatarUrl: HackersPub.URL { __data["avatarUrl"] }
      }
    }
  }

}