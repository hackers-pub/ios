// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI
@_spi(Execution) @_spi(Unsafe) import ApolloAPI

public extension HackersPub {
  struct ViewerQuery: GraphQLQuery {
    public static let operationName: String = "ViewerQuery"
    public static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"query ViewerQuery { viewer { __typename id username name bio avatarUrl handle } }"#
      ))

    public init() {}

    public struct Data: HackersPub.SelectionSet {
      @_spi(Unsafe) public let __data: DataDict
      @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

      @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Query }
      @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
        .field("viewer", Viewer?.self),
      ] }
      @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
        ViewerQuery.Data.self
      ] }

      public var viewer: Viewer? { __data["viewer"] }

      /// Viewer
      ///
      /// Parent Type: `Account`
      public struct Viewer: HackersPub.SelectionSet {
        @_spi(Unsafe) public let __data: DataDict
        @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

        @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Account }
        @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .field("id", HackersPub.ID.self),
          .field("username", String.self),
          .field("name", String.self),
          .field("bio", HackersPub.Markdown.self),
          .field("avatarUrl", HackersPub.URL.self),
          .field("handle", String.self),
        ] }
        @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
          ViewerQuery.Data.Viewer.self
        ] }

        public var id: HackersPub.ID { __data["id"] }
        public var username: String { __data["username"] }
        public var name: String { __data["name"] }
        public var bio: HackersPub.Markdown { __data["bio"] }
        public var avatarUrl: HackersPub.URL { __data["avatarUrl"] }
        public var handle: String { __data["handle"] }
      }
    }
  }

}