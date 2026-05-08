// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI
@_spi(Execution) @_spi(Unsafe) import ApolloAPI

public extension HackersPub {
  struct ActorNotesQuery: GraphQLQuery {
    public static let operationName: String = "ActorNotesQuery"
    public static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"query ActorNotesQuery($handle: String!, $after: String) { actorByHandle(handle: $handle, allowLocalHandle: true) { __typename id notes(first: 20, after: $after) { __typename edges { __typename cursor node { __typename ...ProfilePostFields } } pageInfo { __typename hasNextPage endCursor } } } }"#,
        fragments: [ProfilePostFields.self]
      ))

    public var handle: String
    public var after: GraphQLNullable<String>

    public init(
      handle: String,
      after: GraphQLNullable<String>
    ) {
      self.handle = handle
      self.after = after
    }

    @_spi(Unsafe) public var __variables: Variables? { [
      "handle": handle,
      "after": after
    ] }

    public struct Data: HackersPub.SelectionSet {
      @_spi(Unsafe) public let __data: DataDict
      @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

      @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Query }
      @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
        .field("actorByHandle", ActorByHandle?.self, arguments: [
          "handle": .variable("handle"),
          "allowLocalHandle": true
        ]),
      ] }
      @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
        ActorNotesQuery.Data.self
      ] }

      public var actorByHandle: ActorByHandle? { __data["actorByHandle"] }

      /// ActorByHandle
      ///
      /// Parent Type: `Actor`
      public struct ActorByHandle: HackersPub.SelectionSet {
        @_spi(Unsafe) public let __data: DataDict
        @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

        @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Actor }
        @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .field("id", HackersPub.ID.self),
          .field("notes", Notes.self, arguments: [
            "first": 20,
            "after": .variable("after")
          ]),
        ] }
        @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
          ActorNotesQuery.Data.ActorByHandle.self
        ] }

        public var id: HackersPub.ID { __data["id"] }
        public var notes: Notes { __data["notes"] }

        /// ActorByHandle.Notes
        ///
        /// Parent Type: `ActorNotesConnection`
        public struct Notes: HackersPub.SelectionSet {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.ActorNotesConnection }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("__typename", String.self),
            .field("edges", [Edge].self),
            .field("pageInfo", PageInfo.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            ActorNotesQuery.Data.ActorByHandle.Notes.self
          ] }

          public var edges: [Edge] { __data["edges"] }
          public var pageInfo: PageInfo { __data["pageInfo"] }

          /// ActorByHandle.Notes.Edge
          ///
          /// Parent Type: `ActorNotesConnectionEdge`
          public struct Edge: HackersPub.SelectionSet {
            @_spi(Unsafe) public let __data: DataDict
            @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

            @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.ActorNotesConnectionEdge }
            @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
              .field("__typename", String.self),
              .field("cursor", String.self),
              .field("node", Node.self),
            ] }
            @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
              ActorNotesQuery.Data.ActorByHandle.Notes.Edge.self
            ] }

            public var cursor: String { __data["cursor"] }
            public var node: Node { __data["node"] }

            /// ActorByHandle.Notes.Edge.Node
            ///
            /// Parent Type: `Note`
            public struct Node: HackersPub.SelectionSet {
              @_spi(Unsafe) public let __data: DataDict
              @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

              @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Note }
              @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
                .field("__typename", String.self),
                .fragment(ProfilePostFields.self),
              ] }
              @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                ActorNotesQuery.Data.ActorByHandle.Notes.Edge.Node.self,
                ProfilePostFields.self
              ] }

              public var id: HackersPub.ID { __data["id"] }
              public var name: String? { __data["name"] }
              public var published: HackersPub.DateTime { __data["published"] }
              public var summary: String? { __data["summary"] }
              public var content: HackersPub.HTML { __data["content"] }
              public var excerpt: String { __data["excerpt"] }
              public var url: HackersPub.URL? { __data["url"] }
              public var iri: HackersPub.URL { __data["iri"] }
              public var viewerHasShared: Bool { __data["viewerHasShared"] }
              public var viewerHasBookmarked: Bool { __data["viewerHasBookmarked"] }
              public var actor: Actor { __data["actor"] }
              public var media: [Medium] { __data["media"] }
              public var sharedPost: SharedPost? { __data["sharedPost"] }
              public var quotedPost: QuotedPost? { __data["quotedPost"] }
              public var engagementStats: EngagementStats { __data["engagementStats"] }
              public var reactionGroups: [ReactionGroup] { __data["reactionGroups"] }
              public var mentions: Mentions { __data["mentions"] }

              public struct Fragments: FragmentContainer {
                @_spi(Unsafe) public let __data: DataDict
                @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

                public var profilePostFields: ProfilePostFields { _toFragment() }
              }

              public typealias Actor = ProfilePostFields.Actor

              public typealias Medium = ProfilePostFields.Medium

              public typealias SharedPost = ProfilePostFields.SharedPost

              public typealias QuotedPost = ProfilePostFields.QuotedPost

              public typealias EngagementStats = ProfilePostFields.EngagementStats

              public typealias ReactionGroup = ProfilePostFields.ReactionGroup

              public typealias Mentions = ProfilePostFields.Mentions
            }
          }

          /// ActorByHandle.Notes.PageInfo
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
              ActorNotesQuery.Data.ActorByHandle.Notes.PageInfo.self
            ] }

            public var hasNextPage: Bool { __data["hasNextPage"] }
            public var endCursor: String? { __data["endCursor"] }
          }
        }
      }
    }
  }

}