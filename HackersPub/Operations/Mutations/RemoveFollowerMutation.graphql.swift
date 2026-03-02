// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI
@_spi(Execution) @_spi(Unsafe) import ApolloAPI

public extension HackersPub {
  struct RemoveFollowerMutation: GraphQLMutation {
    public static let operationName: String = "RemoveFollowerMutation"
    public static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"mutation RemoveFollowerMutation($actorId: ID!) { removeFollower(input: { actorId: $actorId }) { __typename ... on RemoveFollowerPayload { followee { __typename id } follower { __typename id } } ... on InvalidInputError { inputPath } ... on NotAuthenticatedError { notAuthenticated } } }"#
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
        .field("removeFollower", RemoveFollower.self, arguments: ["input": ["actorId": .variable("actorId")]]),
      ] }
      @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
        RemoveFollowerMutation.Data.self
      ] }

      public var removeFollower: RemoveFollower { __data["removeFollower"] }

      /// RemoveFollower
      ///
      /// Parent Type: `RemoveFollowerResult`
      public struct RemoveFollower: HackersPub.SelectionSet {
        @_spi(Unsafe) public let __data: DataDict
        @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

        @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Unions.RemoveFollowerResult }
        @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .inlineFragment(AsRemoveFollowerPayload.self),
          .inlineFragment(AsInvalidInputError.self),
          .inlineFragment(AsNotAuthenticatedError.self),
        ] }
        @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
          RemoveFollowerMutation.Data.RemoveFollower.self
        ] }

        public var asRemoveFollowerPayload: AsRemoveFollowerPayload? { _asInlineFragment() }
        public var asInvalidInputError: AsInvalidInputError? { _asInlineFragment() }
        public var asNotAuthenticatedError: AsNotAuthenticatedError? { _asInlineFragment() }

        /// RemoveFollower.AsRemoveFollowerPayload
        ///
        /// Parent Type: `RemoveFollowerPayload`
        public struct AsRemoveFollowerPayload: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = RemoveFollowerMutation.Data.RemoveFollower
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.RemoveFollowerPayload }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("followee", Followee.self),
            .field("follower", Follower.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            RemoveFollowerMutation.Data.RemoveFollower.self,
            RemoveFollowerMutation.Data.RemoveFollower.AsRemoveFollowerPayload.self
          ] }

          public var followee: Followee { __data["followee"] }
          public var follower: Follower { __data["follower"] }

          /// RemoveFollower.AsRemoveFollowerPayload.Followee
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
              RemoveFollowerMutation.Data.RemoveFollower.AsRemoveFollowerPayload.Followee.self
            ] }

            public var id: HackersPub.ID { __data["id"] }
          }

          /// RemoveFollower.AsRemoveFollowerPayload.Follower
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
              RemoveFollowerMutation.Data.RemoveFollower.AsRemoveFollowerPayload.Follower.self
            ] }

            public var id: HackersPub.ID { __data["id"] }
          }
        }

        /// RemoveFollower.AsInvalidInputError
        ///
        /// Parent Type: `InvalidInputError`
        public struct AsInvalidInputError: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = RemoveFollowerMutation.Data.RemoveFollower
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.InvalidInputError }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("inputPath", String.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            RemoveFollowerMutation.Data.RemoveFollower.self,
            RemoveFollowerMutation.Data.RemoveFollower.AsInvalidInputError.self
          ] }

          public var inputPath: String { __data["inputPath"] }
        }

        /// RemoveFollower.AsNotAuthenticatedError
        ///
        /// Parent Type: `NotAuthenticatedError`
        public struct AsNotAuthenticatedError: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = RemoveFollowerMutation.Data.RemoveFollower
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.NotAuthenticatedError }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("notAuthenticated", String.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            RemoveFollowerMutation.Data.RemoveFollower.self,
            RemoveFollowerMutation.Data.RemoveFollower.AsNotAuthenticatedError.self
          ] }

          public var notAuthenticated: String { __data["notAuthenticated"] }
        }
      }
    }
  }

}