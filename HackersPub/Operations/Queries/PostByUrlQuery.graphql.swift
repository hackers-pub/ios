// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI
@_spi(Execution) @_spi(Unsafe) import ApolloAPI

public extension HackersPub {
  struct PostByUrlQuery: GraphQLQuery {
    public static let operationName: String = "PostByUrlQuery"
    public static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"query PostByUrlQuery($url: String!) { postByUrl(url: $url) { __typename id } }"#
      ))

    public var url: String

    public init(url: String) {
      self.url = url
    }

    @_spi(Unsafe) public var __variables: Variables? { ["url": url] }

    public struct Data: HackersPub.SelectionSet {
      @_spi(Unsafe) public let __data: DataDict
      @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

      @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Query }
      @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
        .field("postByUrl", PostByUrl?.self, arguments: ["url": .variable("url")]),
      ] }
      @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
        PostByUrlQuery.Data.self
      ] }

      /// Resolve a post by its URL, fetching it from the originating instance via ActivityPub if it is not already cached. Requires authentication (unauthenticated callers always receive `null`). Returns `null` if the post is not found or not visible to the viewer.
      public var postByUrl: PostByUrl? { __data["postByUrl"] }

      /// PostByUrl
      ///
      /// Parent Type: `Post`
      public struct PostByUrl: HackersPub.SelectionSet {
        @_spi(Unsafe) public let __data: DataDict
        @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

        @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Interfaces.Post }
        @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .field("id", HackersPub.ID.self),
        ] }
        @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
          PostByUrlQuery.Data.PostByUrl.self
        ] }

        public var id: HackersPub.ID { __data["id"] }
      }
    }
  }

}