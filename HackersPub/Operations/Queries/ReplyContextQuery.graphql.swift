// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI
@_spi(Execution) @_spi(Unsafe) import ApolloAPI

public extension HackersPub {
  struct ReplyContextQuery: GraphQLQuery {
    public static let operationName: String = "ReplyContextQuery"
    public static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"query ReplyContextQuery($id: ID!, $after: String, $first: Int!) { node(id: $id) { __typename ... on Post { id visibility actor { __typename handle } mentions(after: $after, first: $first) { __typename edges { __typename node { __typename handle } } pageInfo { __typename hasNextPage endCursor } } } } }"#
      ))

    public var id: ID
    public var after: GraphQLNullable<String>
    public var first: Int32

    public init(
      id: ID,
      after: GraphQLNullable<String>,
      first: Int32
    ) {
      self.id = id
      self.after = after
      self.first = first
    }

    @_spi(Unsafe) public var __variables: Variables? { [
      "id": id,
      "after": after,
      "first": first
    ] }

    public struct Data: HackersPub.SelectionSet {
      @_spi(Unsafe) public let __data: DataDict
      @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

      @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Query }
      @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
        .field("node", Node?.self, arguments: ["id": .variable("id")]),
      ] }
      @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
        ReplyContextQuery.Data.self
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
          ReplyContextQuery.Data.Node.self
        ] }

        public var asPost: AsPost? { _asInlineFragment() }

        /// Node.AsPost
        ///
        /// Parent Type: `Post`
        public struct AsPost: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = ReplyContextQuery.Data.Node
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Interfaces.Post }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("id", HackersPub.ID.self),
            .field("visibility", GraphQLEnum<HackersPub.PostVisibility>.self),
            .field("actor", Actor.self),
            .field("mentions", Mentions.self, arguments: [
              "after": .variable("after"),
              "first": .variable("first")
            ]),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            ReplyContextQuery.Data.Node.self,
            ReplyContextQuery.Data.Node.AsPost.self
          ] }

          public var id: HackersPub.ID { __data["id"] }
          public var visibility: GraphQLEnum<HackersPub.PostVisibility> { __data["visibility"] }
          /// The actor who authored or boosted this post.
          public var actor: Actor { __data["actor"] }
          /// Actors explicitly @-mentioned in this post. Does not include implicit mentions (e.g., the author of the post being replied to). Empty when the post is censored or its author is hidden by a moderation sanction, and the viewer is neither the author nor a moderator, since the mention targets are part of the censored content.
          public var mentions: Mentions { __data["mentions"] }

          /// Node.AsPost.Actor
          ///
          /// Parent Type: `Actor`
          public struct Actor: HackersPub.SelectionSet {
            @_spi(Unsafe) public let __data: DataDict
            @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

            @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Actor }
            @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
              .field("__typename", String.self),
              .field("handle", String.self),
            ] }
            @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
              ReplyContextQuery.Data.Node.AsPost.Actor.self
            ] }

            /// Full fediverse handle in `@username@host` format, ready to use in @-mentions across the fediverse.
            public var handle: String { __data["handle"] }
          }

          /// Node.AsPost.Mentions
          ///
          /// Parent Type: `PostMentionsConnection`
          public struct Mentions: HackersPub.SelectionSet {
            @_spi(Unsafe) public let __data: DataDict
            @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

            @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.PostMentionsConnection }
            @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
              .field("__typename", String.self),
              .field("edges", [Edge].self),
              .field("pageInfo", PageInfo.self),
            ] }
            @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
              ReplyContextQuery.Data.Node.AsPost.Mentions.self
            ] }

            public var edges: [Edge] { __data["edges"] }
            public var pageInfo: PageInfo { __data["pageInfo"] }

            /// Node.AsPost.Mentions.Edge
            ///
            /// Parent Type: `PostMentionsConnectionEdge`
            public struct Edge: HackersPub.SelectionSet {
              @_spi(Unsafe) public let __data: DataDict
              @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

              @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.PostMentionsConnectionEdge }
              @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
                .field("__typename", String.self),
                .field("node", Node.self),
              ] }
              @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                ReplyContextQuery.Data.Node.AsPost.Mentions.Edge.self
              ] }

              public var node: Node { __data["node"] }

              /// Node.AsPost.Mentions.Edge.Node
              ///
              /// Parent Type: `Actor`
              public struct Node: HackersPub.SelectionSet {
                @_spi(Unsafe) public let __data: DataDict
                @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

                @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Actor }
                @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
                  .field("__typename", String.self),
                  .field("handle", String.self),
                ] }
                @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                  ReplyContextQuery.Data.Node.AsPost.Mentions.Edge.Node.self
                ] }

                /// Full fediverse handle in `@username@host` format, ready to use in @-mentions across the fediverse.
                public var handle: String { __data["handle"] }
              }
            }

            /// Node.AsPost.Mentions.PageInfo
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
                ReplyContextQuery.Data.Node.AsPost.Mentions.PageInfo.self
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