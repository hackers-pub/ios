// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI
@_spi(Execution) @_spi(Unsafe) import ApolloAPI

public extension HackersPub {
  struct PostSharesQuery: GraphQLQuery {
    public static let operationName: String = "PostSharesQuery"
    public static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"query PostSharesQuery($id: ID!, $after: String) { node(id: $id) { __typename ... on Post { shares(first: 20, after: $after) { __typename edges { __typename cursor node { __typename id actor { __typename id name handle avatarUrl } } } pageInfo { __typename hasNextPage endCursor } } } } }"#
      ))

    public var id: ID
    public var after: GraphQLNullable<String>

    public init(
      id: ID,
      after: GraphQLNullable<String>
    ) {
      self.id = id
      self.after = after
    }

    @_spi(Unsafe) public var __variables: Variables? { [
      "id": id,
      "after": after
    ] }

    public struct Data: HackersPub.SelectionSet {
      @_spi(Unsafe) public let __data: DataDict
      @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

      @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Query }
      @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
        .field("node", Node?.self, arguments: ["id": .variable("id")]),
      ] }
      @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
        PostSharesQuery.Data.self
      ] }

      public var node: Node? { __data["node"] }

      /// Node
      ///
      /// Parent Type: `Node`
      public struct Node: HackersPub.SelectionSet {
        @_spi(Unsafe) public let __data: DataDict
        @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

        @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Interfaces.Node }
        @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .inlineFragment(AsPost.self),
        ] }
        @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
          PostSharesQuery.Data.Node.self
        ] }

        public var asPost: AsPost? { _asInlineFragment() }

        /// Node.AsPost
        ///
        /// Parent Type: `Post`
        public struct AsPost: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = PostSharesQuery.Data.Node
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Interfaces.Post }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("shares", Shares.self, arguments: [
              "first": 20,
              "after": .variable("after")
            ]),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            PostSharesQuery.Data.Node.self,
            PostSharesQuery.Data.Node.AsPost.self
          ] }

          public var shares: Shares { __data["shares"] }

          /// Node.AsPost.Shares
          ///
          /// Parent Type: `PostSharesConnection`
          public struct Shares: HackersPub.SelectionSet {
            @_spi(Unsafe) public let __data: DataDict
            @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

            @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.PostSharesConnection }
            @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
              .field("__typename", String.self),
              .field("edges", [Edge].self),
              .field("pageInfo", PageInfo.self),
            ] }
            @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
              PostSharesQuery.Data.Node.AsPost.Shares.self
            ] }

            public var edges: [Edge] { __data["edges"] }
            public var pageInfo: PageInfo { __data["pageInfo"] }

            /// Node.AsPost.Shares.Edge
            ///
            /// Parent Type: `PostSharesConnectionEdge`
            public struct Edge: HackersPub.SelectionSet {
              @_spi(Unsafe) public let __data: DataDict
              @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

              @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.PostSharesConnectionEdge }
              @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
                .field("__typename", String.self),
                .field("cursor", String.self),
                .field("node", Node.self),
              ] }
              @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                PostSharesQuery.Data.Node.AsPost.Shares.Edge.self
              ] }

              public var cursor: String { __data["cursor"] }
              public var node: Node { __data["node"] }

              /// Node.AsPost.Shares.Edge.Node
              ///
              /// Parent Type: `Post`
              public struct Node: HackersPub.SelectionSet {
                @_spi(Unsafe) public let __data: DataDict
                @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

                @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Interfaces.Post }
                @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
                  .field("__typename", String.self),
                  .field("id", HackersPub.ID.self),
                  .field("actor", Actor.self),
                ] }
                @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                  PostSharesQuery.Data.Node.AsPost.Shares.Edge.Node.self
                ] }

                public var id: HackersPub.ID { __data["id"] }
                public var actor: Actor { __data["actor"] }

                /// Node.AsPost.Shares.Edge.Node.Actor
                ///
                /// Parent Type: `Actor`
                public struct Actor: HackersPub.SelectionSet {
                  @_spi(Unsafe) public let __data: DataDict
                  @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

                  @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Actor }
                  @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
                    .field("__typename", String.self),
                    .field("id", HackersPub.ID.self),
                    .field("name", HackersPub.HTML?.self),
                    .field("handle", String.self),
                    .field("avatarUrl", HackersPub.URL.self),
                  ] }
                  @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                    PostSharesQuery.Data.Node.AsPost.Shares.Edge.Node.Actor.self
                  ] }

                  public var id: HackersPub.ID { __data["id"] }
                  public var name: HackersPub.HTML? { __data["name"] }
                  public var handle: String { __data["handle"] }
                  public var avatarUrl: HackersPub.URL { __data["avatarUrl"] }
                }
              }
            }

            /// Node.AsPost.Shares.PageInfo
            ///
            /// Parent Type: `PageInfo`
            public struct PageInfo: HackersPub.SelectionSet {
              @_spi(Unsafe) public let __data: DataDict
              @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

              @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.PageInfo }
              @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
                .field("__typename", String.self),
                .field("hasNextPage", Bool.self),
                .field("endCursor", String?.self),
              ] }
              @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                PostSharesQuery.Data.Node.AsPost.Shares.PageInfo.self
              ] }

              public var hasNextPage: Bool { __data["hasNextPage"] }
              public var endCursor: String? { __data["endCursor"] }
            }
          }
        }
      }
    }
  }

}