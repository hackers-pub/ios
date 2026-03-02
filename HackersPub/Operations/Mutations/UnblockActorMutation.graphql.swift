// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI
@_spi(Execution) @_spi(Unsafe) import ApolloAPI

public extension HackersPub {
  struct UnblockActorMutation: GraphQLMutation {
    public static let operationName: String = "UnblockActorMutation"
    public static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"mutation UnblockActorMutation($actorId: ID!) { unblockActor(input: { actorId: $actorId }) { __typename ... on UnblockActorPayload { blockee { __typename id } blocker { __typename id } } ... on InvalidInputError { inputPath } ... on NotAuthenticatedError { notAuthenticated } } }"#
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
        .field("unblockActor", UnblockActor.self, arguments: ["input": ["actorId": .variable("actorId")]]),
      ] }
      @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
        UnblockActorMutation.Data.self
      ] }

      public var unblockActor: UnblockActor { __data["unblockActor"] }

      /// UnblockActor
      ///
      /// Parent Type: `UnblockActorResult`
      public struct UnblockActor: HackersPub.SelectionSet {
        @_spi(Unsafe) public let __data: DataDict
        @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

        @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Unions.UnblockActorResult }
        @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .inlineFragment(AsUnblockActorPayload.self),
          .inlineFragment(AsInvalidInputError.self),
          .inlineFragment(AsNotAuthenticatedError.self),
        ] }
        @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
          UnblockActorMutation.Data.UnblockActor.self
        ] }

        public var asUnblockActorPayload: AsUnblockActorPayload? { _asInlineFragment() }
        public var asInvalidInputError: AsInvalidInputError? { _asInlineFragment() }
        public var asNotAuthenticatedError: AsNotAuthenticatedError? { _asInlineFragment() }

        /// UnblockActor.AsUnblockActorPayload
        ///
        /// Parent Type: `UnblockActorPayload`
        public struct AsUnblockActorPayload: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = UnblockActorMutation.Data.UnblockActor
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.UnblockActorPayload }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("blockee", Blockee.self),
            .field("blocker", Blocker.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            UnblockActorMutation.Data.UnblockActor.self,
            UnblockActorMutation.Data.UnblockActor.AsUnblockActorPayload.self
          ] }

          public var blockee: Blockee { __data["blockee"] }
          public var blocker: Blocker { __data["blocker"] }

          /// UnblockActor.AsUnblockActorPayload.Blockee
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
              UnblockActorMutation.Data.UnblockActor.AsUnblockActorPayload.Blockee.self
            ] }

            public var id: HackersPub.ID { __data["id"] }
          }

          /// UnblockActor.AsUnblockActorPayload.Blocker
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
              UnblockActorMutation.Data.UnblockActor.AsUnblockActorPayload.Blocker.self
            ] }

            public var id: HackersPub.ID { __data["id"] }
          }
        }

        /// UnblockActor.AsInvalidInputError
        ///
        /// Parent Type: `InvalidInputError`
        public struct AsInvalidInputError: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = UnblockActorMutation.Data.UnblockActor
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.InvalidInputError }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("inputPath", String.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            UnblockActorMutation.Data.UnblockActor.self,
            UnblockActorMutation.Data.UnblockActor.AsInvalidInputError.self
          ] }

          public var inputPath: String { __data["inputPath"] }
        }

        /// UnblockActor.AsNotAuthenticatedError
        ///
        /// Parent Type: `NotAuthenticatedError`
        public struct AsNotAuthenticatedError: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = UnblockActorMutation.Data.UnblockActor
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.NotAuthenticatedError }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("notAuthenticated", String.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            UnblockActorMutation.Data.UnblockActor.self,
            UnblockActorMutation.Data.UnblockActor.AsNotAuthenticatedError.self
          ] }

          public var notAuthenticated: String { __data["notAuthenticated"] }
        }
      }
    }
  }

}