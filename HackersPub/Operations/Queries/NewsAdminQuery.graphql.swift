// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI
@_spi(Execution) @_spi(Unsafe) import ApolloAPI

public extension HackersPub {
  struct NewsAdminQuery: GraphQLQuery {
    public static let operationName: String = "NewsAdminQuery"
    public static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"query NewsAdminQuery { viewer { __typename id moderator } newsScoreStatus { __typename scoredLinkCount lastRecomputedAt } newsExcludedPatterns { __typename id pattern note created } newsPenalizedStories { __typename id uuid url title penalty } }"#
      ))

    public init() {}

    public struct Data: HackersPub.SelectionSet {
      @_spi(Unsafe) public let __data: DataDict
      @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

      @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Query }
      @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
        .field("viewer", Viewer?.self),
        .field("newsScoreStatus", NewsScoreStatus?.self),
        .field("newsExcludedPatterns", [NewsExcludedPattern]?.self),
        .field("newsPenalizedStories", [NewsPenalizedStory]?.self),
      ] }
      @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
        NewsAdminQuery.Data.self
      ] }

      /// The `Account` of the currently authenticated user, or `null` when not authenticated. Use this as the entry point for all viewer-specific data (notifications, drafts, settings).
      public var viewer: Viewer? { __data["viewer"] }
      /// Moderator-only news scoring snapshot.  Returns `null` when the viewer is not a moderator; routes should guard with `viewer.moderator`.
      public var newsScoreStatus: NewsScoreStatus? { __data["newsScoreStatus"] }
      /// Moderator-only list of news feed exclusion patterns, newest first.  `null` for non-moderators.
      public var newsExcludedPatterns: [NewsExcludedPattern]? { __data["newsExcludedPatterns"] }
      /// Moderator-only list of news links currently carrying a score penalty, heaviest first, for reviewing/clearing demotions (a buried link is no longer near the top of the feed).  `null` for non-moderators.
      public var newsPenalizedStories: [NewsPenalizedStory]? { __data["newsPenalizedStories"] }

      /// Viewer
      ///
      /// Parent Type: `Account`
      public struct Viewer: HackersPub.SelectionSet {
        @_spi(Unsafe) public let __data: DataDict
        @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

        @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Account }
        @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .field("id", HackersPub.ID.self),
          .field("moderator", Bool.self),
        ] }
        @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
          NewsAdminQuery.Data.Viewer.self
        ] }

        public var id: HackersPub.ID { __data["id"] }
        /// Whether this account has moderator privileges. Moderators can view all accounts, see moderation-only fields such as `postCount` and `lastPostPublished`, and perform administrative mutations such as `deleteOrphanMedia` and `regenerateInvitations`.
        public var moderator: Bool { __data["moderator"] }
      }

      /// NewsScoreStatus
      ///
      /// Parent Type: `NewsScoreStatus`
      public struct NewsScoreStatus: HackersPub.SelectionSet {
        @_spi(Unsafe) public let __data: DataDict
        @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

        @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.NewsScoreStatus }
        @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .field("scoredLinkCount", Int.self),
          .field("lastRecomputedAt", HackersPub.DateTime?.self),
        ] }
        @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
          NewsAdminQuery.Data.NewsScoreStatus.self
        ] }

        /// Number of links currently in the feed (with at least one public share).
        public var scoredLinkCount: Int { __data["scoredLinkCount"] }
        /// When scores were last recomputed, or `null` if never.
        public var lastRecomputedAt: HackersPub.DateTime? { __data["lastRecomputedAt"] }
      }

      /// NewsExcludedPattern
      ///
      /// Parent Type: `NewsExcludedPattern`
      public struct NewsExcludedPattern: HackersPub.SelectionSet {
        @_spi(Unsafe) public let __data: DataDict
        @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

        @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.NewsExcludedPattern }
        @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .field("id", HackersPub.UUID.self),
          .field("pattern", String.self),
          .field("note", String?.self),
          .field("created", HackersPub.DateTime.self),
        ] }
        @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
          NewsAdminQuery.Data.NewsExcludedPattern.self
        ] }

        /// The pattern's row UUID.
        public var id: HackersPub.UUID { __data["id"] }
        /// The `URLPattern` string, e.g. `https://example.com/*` or `https://*.example.com/*`.
        public var pattern: String { __data["pattern"] }
        /// An optional moderator note explaining the exclusion.
        public var note: String? { __data["note"] }
        /// When the pattern was added.
        public var created: HackersPub.DateTime { __data["created"] }
      }

      /// NewsPenalizedStory
      ///
      /// Parent Type: `PostLink`
      public struct NewsPenalizedStory: HackersPub.SelectionSet {
        @_spi(Unsafe) public let __data: DataDict
        @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

        @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.PostLink }
        @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .field("id", HackersPub.ID.self),
          .field("uuid", HackersPub.UUID.self),
          .field("url", HackersPub.URL.self),
          .field("title", String?.self),
          .field("penalty", GraphQLEnum<HackersPub.NewsPenalty>?.self),
        ] }
        @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
          NewsAdminQuery.Data.NewsPenalizedStory.self
        ] }

        public var id: HackersPub.ID { __data["id"] }
        /// The link's row UUID.  Use this for the stable discussion permalink `/news/{uuid}`; the opaque Relay `id` is for `node(id:)` lookups.
        public var uuid: HackersPub.UUID { __data["uuid"] }
        public var url: HackersPub.URL { __data["url"] }
        public var title: String? { __data["title"] }
        /// The moderator score penalty on this link (demoting it in the `POPULAR` feed).  `null` for non-moderators; moderators see `NONE` when the link is unpenalized.  Set it with `setNewsScorePenalty`.
        public var penalty: GraphQLEnum<HackersPub.NewsPenalty>? { __data["penalty"] }
      }
    }
  }

}