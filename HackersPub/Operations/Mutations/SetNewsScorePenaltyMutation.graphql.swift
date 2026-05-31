// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI
@_spi(Execution) @_spi(Unsafe) import ApolloAPI

public extension HackersPub {
  struct SetNewsScorePenaltyMutation: GraphQLMutation {
    public static let operationName: String = "SetNewsScorePenaltyMutation"
    public static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"mutation SetNewsScorePenaltyMutation($id: UUID!, $penalty: NewsPenalty!) { setNewsScorePenalty(id: $id, penalty: $penalty) { __typename ... on PostLink { id penalty } ... on NotAuthenticatedError { notAuthenticated } ... on NotAuthorizedError { notAuthorized } } }"#
      ))

    public var id: UUID
    public var penalty: GraphQLEnum<NewsPenalty>

    public init(
      id: UUID,
      penalty: GraphQLEnum<NewsPenalty>
    ) {
      self.id = id
      self.penalty = penalty
    }

    @_spi(Unsafe) public var __variables: Variables? { [
      "id": id,
      "penalty": penalty
    ] }

    public struct Data: HackersPub.SelectionSet {
      @_spi(Unsafe) public let __data: DataDict
      @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

      @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Mutation }
      @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
        .field("setNewsScorePenalty", SetNewsScorePenalty?.self, arguments: [
          "id": .variable("id"),
          "penalty": .variable("penalty")
        ]),
      ] }
      @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
        SetNewsScorePenaltyMutation.Data.self
      ] }

      /// Set (or clear with `NONE`) a moderator score penalty on a news link, demoting it in the `POPULAR` feed.  Requires a moderator account.  Returns the updated link, or `null` if no link has that id.
      public var setNewsScorePenalty: SetNewsScorePenalty? { __data["setNewsScorePenalty"] }

      /// SetNewsScorePenalty
      ///
      /// Parent Type: `SetNewsScorePenaltyResult`
      public struct SetNewsScorePenalty: HackersPub.SelectionSet {
        @_spi(Unsafe) public let __data: DataDict
        @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

        @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Unions.SetNewsScorePenaltyResult }
        @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .inlineFragment(AsPostLink.self),
          .inlineFragment(AsNotAuthenticatedError.self),
          .inlineFragment(AsNotAuthorizedError.self),
        ] }
        @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
          SetNewsScorePenaltyMutation.Data.SetNewsScorePenalty.self
        ] }

        public var asPostLink: AsPostLink? { _asInlineFragment() }
        public var asNotAuthenticatedError: AsNotAuthenticatedError? { _asInlineFragment() }
        public var asNotAuthorizedError: AsNotAuthorizedError? { _asInlineFragment() }

        /// SetNewsScorePenalty.AsPostLink
        ///
        /// Parent Type: `PostLink`
        public struct AsPostLink: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = SetNewsScorePenaltyMutation.Data.SetNewsScorePenalty
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.PostLink }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("id", HackersPub.ID.self),
            .field("penalty", GraphQLEnum<HackersPub.NewsPenalty>?.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            SetNewsScorePenaltyMutation.Data.SetNewsScorePenalty.self,
            SetNewsScorePenaltyMutation.Data.SetNewsScorePenalty.AsPostLink.self
          ] }

          public var id: HackersPub.ID { __data["id"] }
          /// The moderator score penalty on this link (demoting it in the `POPULAR` feed).  `null` for non-moderators; moderators see `NONE` when the link is unpenalized.  Set it with `setNewsScorePenalty`.
          public var penalty: GraphQLEnum<HackersPub.NewsPenalty>? { __data["penalty"] }
        }

        /// SetNewsScorePenalty.AsNotAuthenticatedError
        ///
        /// Parent Type: `NotAuthenticatedError`
        public struct AsNotAuthenticatedError: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = SetNewsScorePenaltyMutation.Data.SetNewsScorePenalty
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.NotAuthenticatedError }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("notAuthenticated", String.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            SetNewsScorePenaltyMutation.Data.SetNewsScorePenalty.self,
            SetNewsScorePenaltyMutation.Data.SetNewsScorePenalty.AsNotAuthenticatedError.self
          ] }

          public var notAuthenticated: String { __data["notAuthenticated"] }
        }

        /// SetNewsScorePenalty.AsNotAuthorizedError
        ///
        /// Parent Type: `NotAuthorizedError`
        public struct AsNotAuthorizedError: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = SetNewsScorePenaltyMutation.Data.SetNewsScorePenalty
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.NotAuthorizedError }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("notAuthorized", String.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            SetNewsScorePenaltyMutation.Data.SetNewsScorePenalty.self,
            SetNewsScorePenaltyMutation.Data.SetNewsScorePenalty.AsNotAuthorizedError.self
          ] }

          public var notAuthorized: String { __data["notAuthorized"] }
        }
      }
    }
  }

}