// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI
@_spi(Execution) @_spi(Unsafe) import ApolloAPI

public extension HackersPub {
  struct UnfollowActorMutation: GraphQLMutation {
    public static let operationName: String = "UnfollowActorMutation"
    public static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"mutation UnfollowActorMutation($actorId: ID!) { unfollowActor(input: { actorId: $actorId }) { __typename ... on UnfollowActorPayload { followee { __typename id } follower { __typename id } } ... on InvalidInputError { inputPath } ... on NotAuthenticatedError { notAuthenticated } } }"#
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
        .field("unfollowActor", UnfollowActor.self, arguments: ["input": ["actorId": .variable("actorId")]]),
      ] }
      @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
        UnfollowActorMutation.Data.self
      ] }

      public var unfollowActor: UnfollowActor { __data["unfollowActor"] }

      /// UnfollowActor
      ///
      /// Parent Type: `UnfollowActorResult`
      public struct UnfollowActor: HackersPub.SelectionSet {
        @_spi(Unsafe) public let __data: DataDict
        @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

        @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Unions.UnfollowActorResult }
        @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .inlineFragment(AsUnfollowActorPayload.self),
          .inlineFragment(AsInvalidInputError.self),
          .inlineFragment(AsNotAuthenticatedError.self),
        ] }
        @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
          UnfollowActorMutation.Data.UnfollowActor.self
        ] }

        public var asUnfollowActorPayload: AsUnfollowActorPayload? { _asInlineFragment() }
        public var asInvalidInputError: AsInvalidInputError? { _asInlineFragment() }
        public var asNotAuthenticatedError: AsNotAuthenticatedError? { _asInlineFragment() }

        /// UnfollowActor.AsUnfollowActorPayload
        ///
        /// Parent Type: `UnfollowActorPayload`
        public struct AsUnfollowActorPayload: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = UnfollowActorMutation.Data.UnfollowActor
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.UnfollowActorPayload }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("followee", Followee.self),
            .field("follower", Follower.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            UnfollowActorMutation.Data.UnfollowActor.self,
            UnfollowActorMutation.Data.UnfollowActor.AsUnfollowActorPayload.self
          ] }

          public var followee: Followee { __data["followee"] }
          public var follower: Follower { __data["follower"] }

          /// UnfollowActor.AsUnfollowActorPayload.Followee
          ///
          /// Parent Type: `Actor`
          public struct Followee: HackersPub.SelectionSet {
            @_spi(Unsafe) public let __data: DataDict
            @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

            @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Actor }
            @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
              .field("__typename", String.self),
              .field("id", HackersPub.ID.self),
            ] }
            @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
              UnfollowActorMutation.Data.UnfollowActor.AsUnfollowActorPayload.Followee.self
            ] }

            public var id: HackersPub.ID { __data["id"] }
          }

          /// UnfollowActor.AsUnfollowActorPayload.Follower
          ///
          /// Parent Type: `Actor`
          public struct Follower: HackersPub.SelectionSet {
            @_spi(Unsafe) public let __data: DataDict
            @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

            @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Actor }
            @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
              .field("__typename", String.self),
              .field("id", HackersPub.ID.self),
            ] }
            @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
              UnfollowActorMutation.Data.UnfollowActor.AsUnfollowActorPayload.Follower.self
            ] }

            public var id: HackersPub.ID { __data["id"] }
          }
        }

        /// UnfollowActor.AsInvalidInputError
        ///
        /// Parent Type: `InvalidInputError`
        public struct AsInvalidInputError: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = UnfollowActorMutation.Data.UnfollowActor
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.InvalidInputError }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("inputPath", String.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            UnfollowActorMutation.Data.UnfollowActor.self,
            UnfollowActorMutation.Data.UnfollowActor.AsInvalidInputError.self
          ] }

          public var inputPath: String { __data["inputPath"] }
        }

        /// UnfollowActor.AsNotAuthenticatedError
        ///
        /// Parent Type: `NotAuthenticatedError`
        public struct AsNotAuthenticatedError: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = UnfollowActorMutation.Data.UnfollowActor
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.NotAuthenticatedError }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("notAuthenticated", String.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            UnfollowActorMutation.Data.UnfollowActor.self,
            UnfollowActorMutation.Data.UnfollowActor.AsNotAuthenticatedError.self
          ] }

          public var notAuthenticated: String { __data["notAuthenticated"] }
        }
      }
    }
  }

}