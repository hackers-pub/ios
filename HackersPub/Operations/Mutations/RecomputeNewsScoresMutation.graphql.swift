// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI
@_spi(Execution) @_spi(Unsafe) import ApolloAPI

public extension HackersPub {
  struct RecomputeNewsScoresMutation: GraphQLMutation {
    public static let operationName: String = "RecomputeNewsScoresMutation"
    public static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"mutation RecomputeNewsScoresMutation { recomputeNewsScores { __typename ... on RecomputeNewsScoresPayload { linksUpdated status { __typename scoredLinkCount lastRecomputedAt } } ... on NotAuthenticatedError { notAuthenticated } ... on NotAuthorizedError { notAuthorized } } }"#
      ))

    public init() {}

    public struct Data: HackersPub.SelectionSet {
      @_spi(Unsafe) public let __data: DataDict
      @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

      @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Mutation }
      @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
        .field("recomputeNewsScores", RecomputeNewsScores.self),
      ] }
      @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
        RecomputeNewsScoresMutation.Data.self
      ] }

      /// Recompute popularity scores for every news link.  Requires a moderator account.  Idempotent: safe to trigger at any time, and running it twice on unchanged data yields identical scores.  Normally scores stay fresh on their own (incrementally on share, plus a periodic sweep); this is the manual full rebuild and dev backstop.
      public var recomputeNewsScores: RecomputeNewsScores { __data["recomputeNewsScores"] }

      /// RecomputeNewsScores
      ///
      /// Parent Type: `RecomputeNewsScoresResult`
      public struct RecomputeNewsScores: HackersPub.SelectionSet {
        @_spi(Unsafe) public let __data: DataDict
        @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

        @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Unions.RecomputeNewsScoresResult }
        @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .inlineFragment(AsRecomputeNewsScoresPayload.self),
          .inlineFragment(AsNotAuthenticatedError.self),
          .inlineFragment(AsNotAuthorizedError.self),
        ] }
        @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
          RecomputeNewsScoresMutation.Data.RecomputeNewsScores.self
        ] }

        public var asRecomputeNewsScoresPayload: AsRecomputeNewsScoresPayload? { _asInlineFragment() }
        public var asNotAuthenticatedError: AsNotAuthenticatedError? { _asInlineFragment() }
        public var asNotAuthorizedError: AsNotAuthorizedError? { _asInlineFragment() }

        /// RecomputeNewsScores.AsRecomputeNewsScoresPayload
        ///
        /// Parent Type: `RecomputeNewsScoresPayload`
        public struct AsRecomputeNewsScoresPayload: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = RecomputeNewsScoresMutation.Data.RecomputeNewsScores
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.RecomputeNewsScoresPayload }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("linksUpdated", Int.self),
            .field("status", Status.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            RecomputeNewsScoresMutation.Data.RecomputeNewsScores.self,
            RecomputeNewsScoresMutation.Data.RecomputeNewsScores.AsRecomputeNewsScoresPayload.self
          ] }

          /// Number of links with at least one qualifying public share that were (re)scored by this run.  Stale links dropped from the feed (they lost their last public share) are reset to zero but not counted here.
          public var linksUpdated: Int { __data["linksUpdated"] }
          /// The scoring status after the run.
          public var status: Status { __data["status"] }

          /// RecomputeNewsScores.AsRecomputeNewsScoresPayload.Status
          ///
          /// Parent Type: `NewsScoreStatus`
          public struct Status: HackersPub.SelectionSet {
            @_spi(Unsafe) public let __data: DataDict
            @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

            @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.NewsScoreStatus }
            @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
              .field("__typename", String.self),
              .field("scoredLinkCount", Int.self),
              .field("lastRecomputedAt", HackersPub.DateTime?.self),
            ] }
            @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
              RecomputeNewsScoresMutation.Data.RecomputeNewsScores.AsRecomputeNewsScoresPayload.Status.self
            ] }

            /// Number of links currently in the feed (with at least one public share).
            public var scoredLinkCount: Int { __data["scoredLinkCount"] }
            /// When scores were last recomputed, or `null` if never.
            public var lastRecomputedAt: HackersPub.DateTime? { __data["lastRecomputedAt"] }
          }
        }

        /// RecomputeNewsScores.AsNotAuthenticatedError
        ///
        /// Parent Type: `NotAuthenticatedError`
        public struct AsNotAuthenticatedError: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = RecomputeNewsScoresMutation.Data.RecomputeNewsScores
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.NotAuthenticatedError }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("notAuthenticated", String.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            RecomputeNewsScoresMutation.Data.RecomputeNewsScores.self,
            RecomputeNewsScoresMutation.Data.RecomputeNewsScores.AsNotAuthenticatedError.self
          ] }

          public var notAuthenticated: String { __data["notAuthenticated"] }
        }

        /// RecomputeNewsScores.AsNotAuthorizedError
        ///
        /// Parent Type: `NotAuthorizedError`
        public struct AsNotAuthorizedError: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = RecomputeNewsScoresMutation.Data.RecomputeNewsScores
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.NotAuthorizedError }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("notAuthorized", String.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            RecomputeNewsScoresMutation.Data.RecomputeNewsScores.self,
            RecomputeNewsScoresMutation.Data.RecomputeNewsScores.AsNotAuthorizedError.self
          ] }

          public var notAuthorized: String { __data["notAuthorized"] }
        }
      }
    }
  }

}