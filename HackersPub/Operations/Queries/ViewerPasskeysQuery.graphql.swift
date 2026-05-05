// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI
@_spi(Execution) @_spi(Unsafe) import ApolloAPI

public extension HackersPub {
  struct ViewerPasskeysQuery: GraphQLQuery {
    public static let operationName: String = "ViewerPasskeysQuery"
    public static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"query ViewerPasskeysQuery { viewer { __typename id passkeys(first: 50) { __typename edges { __typename node { __typename id name created lastUsed } } } } }"#
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
        ViewerPasskeysQuery.Data.self
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
          .field("passkeys", Passkeys.self, arguments: ["first": 50]),
        ] }
        @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
          ViewerPasskeysQuery.Data.Viewer.self
        ] }

        public var id: HackersPub.ID { __data["id"] }
        public var passkeys: Passkeys { __data["passkeys"] }

        /// Viewer.Passkeys
        ///
        /// Parent Type: `AccountPasskeysConnection`
        public struct Passkeys: HackersPub.SelectionSet {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.AccountPasskeysConnection }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("__typename", String.self),
            .field("edges", [Edge].self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            ViewerPasskeysQuery.Data.Viewer.Passkeys.self
          ] }

          public var edges: [Edge] { __data["edges"] }

          /// Viewer.Passkeys.Edge
          ///
          /// Parent Type: `AccountPasskeysConnectionEdge`
          public struct Edge: HackersPub.SelectionSet {
            @_spi(Unsafe) public let __data: DataDict
            @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

            @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.AccountPasskeysConnectionEdge }
            @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
              .field("__typename", String.self),
              .field("node", Node.self),
            ] }
            @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
              ViewerPasskeysQuery.Data.Viewer.Passkeys.Edge.self
            ] }

            public var node: Node { __data["node"] }

            /// Viewer.Passkeys.Edge.Node
            ///
            /// Parent Type: `Passkey`
            public struct Node: HackersPub.SelectionSet {
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
                ViewerPasskeysQuery.Data.Viewer.Passkeys.Edge.Node.self
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
  }

}