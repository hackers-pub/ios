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
        public var handle: String { __data["handle"] }
        public var isViewer: Bool { __data["isViewer"] }
        public var viewerFollows: Bool { __data["viewerFollows"] }
        public var followsViewer: Bool { __data["followsViewer"] }
        public var viewerBlocks: Bool { __data["viewerBlocks"] }
      }
    }
  }

}