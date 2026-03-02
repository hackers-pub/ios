// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI
@_spi(Execution) @_spi(Unsafe) import ApolloAPI

public extension HackersPub {
  struct BlockActorMutation: GraphQLMutation {
    public static let operationName: String = "BlockActorMutation"
    public static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"mutation BlockActorMutation($actorId: ID!) { blockActor(input: { actorId: $actorId }) { __typename ... on BlockActorPayload { blockee { __typename id } blocker { __typename id } } ... on InvalidInputError { inputPath } ... on NotAuthenticatedError { notAuthenticated } } }"#
      ))

    public var actorId: ID

    public init(actorId: ID) {
      self.actorId = actorId
    }

    @_spi(Unsafe) public var __variables: Variables? { ["actorId": actorId] }

    public struct Data: HackersPub.SelectionSet {
      @_spi(Unsafe) public let __data: DataDict
      @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

      @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Mutation }
      @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
        .field("blockActor", BlockActor.self, arguments: ["input": ["actorId": .variable("actorId")]]),
      ] }
      @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
        BlockActorMutation.Data.self
      ] }

      public var blockActor: BlockActor { __data["blockActor"] }

      /// BlockActor
      ///
      /// Parent Type: `BlockActorResult`
      public struct BlockActor: HackersPub.SelectionSet {
        @_spi(Unsafe) public let __data: DataDict
        @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

        @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Unions.BlockActorResult }
        @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .inlineFragment(AsBlockActorPayload.self),
          .inlineFragment(AsInvalidInputError.self),
          .inlineFragment(AsNotAuthenticatedError.self),
        ] }
        @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
          BlockActorMutation.Data.BlockActor.self
        ] }

        public var asBlockActorPayload: AsBlockActorPayload? { _asInlineFragment() }
        public var asInvalidInputError: AsInvalidInputError? { _asInlineFragment() }
        public var asNotAuthenticatedError: AsNotAuthenticatedError? { _asInlineFragment() }

        /// BlockActor.AsBlockActorPayload
        ///
        /// Parent Type: `BlockActorPayload`
        public struct AsBlockActorPayload: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = BlockActorMutation.Data.BlockActor
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.BlockActorPayload }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("blockee", Blockee.self),
            .field("blocker", Blocker.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            BlockActorMutation.Data.BlockActor.self,
            BlockActorMutation.Data.BlockActor.AsBlockActorPayload.self
          ] }

          public var blockee: Blockee { __data["blockee"] }
          public var blocker: Blocker { __data["blocker"] }

          /// BlockActor.AsBlockActorPayload.Blockee
          ///
          /// Parent Type: `Actor`
          public struct Blockee: HackersPub.SelectionSet {
            @_spi(Unsafe) public let __data: DataDict
            @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

            @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Actor }
            @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
              .field("__typename", String.self),
              .field("id", HackersPub.ID.self),
            ] }
            @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
              BlockActorMutation.Data.BlockActor.AsBlockActorPayload.Blockee.self
            ] }

            public var id: HackersPub.ID { __data["id"] }
          }

          /// BlockActor.AsBlockActorPayload.Blocker
          ///
          /// Parent Type: `Actor`
          public struct Blocker: HackersPub.SelectionSet {
            @_spi(Unsafe) public let __data: DataDict
            @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

            @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Actor }
            @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
              .field("__typename", String.self),
              .field("id", HackersPub.ID.self),
            ] }
            @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
              BlockActorMutation.Data.BlockActor.AsBlockActorPayload.Blocker.self
            ] }

            public var id: HackersPub.ID { __data["id"] }
          }
        }

        /// BlockActor.AsInvalidInputError
        ///
        /// Parent Type: `InvalidInputError`
        public struct AsInvalidInputError: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = BlockActorMutation.Data.BlockActor
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.InvalidInputError }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("inputPath", String.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            BlockActorMutation.Data.BlockActor.self,
            BlockActorMutation.Data.BlockActor.AsInvalidInputError.self
          ] }

          public var inputPath: String { __data["inputPath"] }
        }

        /// BlockActor.AsNotAuthenticatedError
        ///
        /// Parent Type: `NotAuthenticatedError`
        public struct AsNotAuthenticatedError: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = BlockActorMutation.Data.BlockActor
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.NotAuthenticatedError }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("notAuthenticated", String.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            BlockActorMutation.Data.BlockActor.self,
            BlockActorMutation.Data.BlockActor.AsNotAuthenticatedError.self
          ] }

          public var notAuthenticated: String { __data["notAuthenticated"] }
        }
      }
    }
  }

}