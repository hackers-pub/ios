// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI
@_spi(Execution) @_spi(Unsafe) import ApolloAPI

public extension HackersPub {
  struct FollowActorMutation: GraphQLMutation {
    public static let operationName: String = "FollowActorMutation"
    public static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"mutation FollowActorMutation($actorId: ID!) { followActor(input: { actorId: $actorId }) { __typename ... on FollowActorPayload { followee { __typename id } follower { __typename id } } ... on InvalidInputError { inputPath } ... on NotAuthenticatedError { notAuthenticated } } }"#
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
        .field("followActor", FollowActor.self, arguments: ["input": ["actorId": .variable("actorId")]]),
      ] }
      @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
        FollowActorMutation.Data.self
      ] }

      public var followActor: FollowActor { __data["followActor"] }

      /// FollowActor
      ///
      /// Parent Type: `FollowActorResult`
      public struct FollowActor: HackersPub.SelectionSet {
        @_spi(Unsafe) public let __data: DataDict
        @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

        @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Unions.FollowActorResult }
        @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .inlineFragment(AsFollowActorPayload.self),
          .inlineFragment(AsInvalidInputError.self),
          .inlineFragment(AsNotAuthenticatedError.self),
        ] }
        @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
          FollowActorMutation.Data.FollowActor.self
        ] }

        public var asFollowActorPayload: AsFollowActorPayload? { _asInlineFragment() }
        public var asInvalidInputError: AsInvalidInputError? { _asInlineFragment() }
        public var asNotAuthenticatedError: AsNotAuthenticatedError? { _asInlineFragment() }

        /// FollowActor.AsFollowActorPayload
        ///
        /// Parent Type: `FollowActorPayload`
        public struct AsFollowActorPayload: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = FollowActorMutation.Data.FollowActor
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.FollowActorPayload }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("followee", Followee.self),
            .field("follower", Follower.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            FollowActorMutation.Data.FollowActor.self,
            FollowActorMutation.Data.FollowActor.AsFollowActorPayload.self
          ] }

          public var followee: Followee { __data["followee"] }
          public var follower: Follower { __data["follower"] }

          /// FollowActor.AsFollowActorPayload.Followee
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
              FollowActorMutation.Data.FollowActor.AsFollowActorPayload.Followee.self
            ] }

            public var id: HackersPub.ID { __data["id"] }
          }

          /// FollowActor.AsFollowActorPayload.Follower
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
              FollowActorMutation.Data.FollowActor.AsFollowActorPayload.Follower.self
            ] }

            public var id: HackersPub.ID { __data["id"] }
          }
        }

        /// FollowActor.AsInvalidInputError
        ///
        /// Parent Type: `InvalidInputError`
        public struct AsInvalidInputError: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = FollowActorMutation.Data.FollowActor
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.InvalidInputError }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("inputPath", String.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            FollowActorMutation.Data.FollowActor.self,
            FollowActorMutation.Data.FollowActor.AsInvalidInputError.self
          ] }

          public var inputPath: String { __data["inputPath"] }
        }

        /// FollowActor.AsNotAuthenticatedError
        ///
        /// Parent Type: `NotAuthenticatedError`
        public struct AsNotAuthenticatedError: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = FollowActorMutation.Data.FollowActor
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.NotAuthenticatedError }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("notAuthenticated", String.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            FollowActorMutation.Data.FollowActor.self,
            FollowActorMutation.Data.FollowActor.AsNotAuthenticatedError.self
          ] }

          public var notAuthenticated: String { __data["notAuthenticated"] }
        }
      }
    }
  }

}