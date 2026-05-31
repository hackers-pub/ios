// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI
@_spi(Execution) @_spi(Unsafe) import ApolloAPI

public extension HackersPub {
  struct ActorRelationshipQuery: GraphQLQuery {
    public static let operationName: String = "ActorRelationshipQuery"
    public static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"query ActorRelationshipQuery($handle: String!) { actorByHandle(handle: $handle, allowLocalHandle: true) { __typename id handle isViewer viewerFollows followsViewer viewerBlocks } }"#
      ))

    public var handle: String

    public init(handle: String) {
      self.handle = handle
    }

    @_spi(Unsafe) public var __variables: Variables? { ["handle": handle] }

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
        ActorRelationshipQuery.Data.self
      ] }

      /// Look up an actor by their fediverse handle (e.g., `@alice@mastodon.social` or `alice@hackers.pub`). For `user@host` handles not already in the local cache, triggers an outbound WebFinger + ActivityPub fetch and persists the result; this only happens for authenticated requests, since unauthenticated callers are not allowed to spawn outbound federation lookups.
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
          .field("handle", String.self),
          .field("isViewer", Bool.self),
          .field("viewerFollows", Bool.self),
          .field("followsViewer", Bool.self),
          .field("viewerBlocks", Bool.self),
        ] }
        @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
          ActorRelationshipQuery.Data.ActorByHandle.self
        ] }

        public var id: HackersPub.ID { __data["id"] }
        /// Full fediverse handle in `@username@host` format, ready to use in @-mentions across the fediverse.
        public var handle: String { __data["handle"] }
        /// True if this actor belongs to the currently authenticated viewer. Always false for unauthenticated requests.
        public var isViewer: Bool { __data["isViewer"] }
        /// True if the authenticated viewer follows this actor. Always false for unauthenticated requests or when the actor is the viewer themselves.
        public var viewerFollows: Bool { __data["viewerFollows"] }
        /// True if this actor follows the authenticated viewer. Always false for unauthenticated requests.
        public var followsViewer: Bool { __data["followsViewer"] }
        /// True if the authenticated viewer has blocked this actor. Always false for unauthenticated requests.
        public var viewerBlocks: Bool { __data["viewerBlocks"] }
      }
    }
  }

}