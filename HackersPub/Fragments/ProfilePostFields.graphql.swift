// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI
@_spi(Execution) @_spi(Unsafe) import ApolloAPI

public extension HackersPub {
  struct ProfilePostFields: HackersPub.SelectionSet, Fragment {
    public static var fragmentDefinition: StaticString {
      #"fragment ProfilePostFields on Post { __typename id name published summary content excerpt url iri viewerHasShared viewerHasBookmarked actor { __typename id name handle avatarUrl } media { __typename url thumbnailUrl alt height width } sharedPost { __typename id name published summary content excerpt url iri viewerHasShared viewerHasBookmarked actor { __typename id name handle avatarUrl } media { __typename url thumbnailUrl alt height width } engagementStats { __typename replies reactions shares quotes } mentions(first: 20) { __typename edges { __typename node { __typename handle } } } } quotedPost { __typename id name published summary content excerpt url iri actor { __typename id name handle avatarUrl } media { __typename url thumbnailUrl alt height width } } engagementStats { __typename replies reactions shares quotes } reactionGroups { __typename ... on EmojiReactionGroup { emoji reactors { __typename totalCount viewerHasReacted } } ... on CustomEmojiReactionGroup { customEmoji { __typename id name imageUrl } reactors { __typename totalCount viewerHasReacted } } } mentions(first: 20) { __typename edges { __typename node { __typename id handle } } } }"#
    }

    @_spi(Unsafe) public let __data: DataDict
    @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

    @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Interfaces.Post }
    @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
      .field("__typename", String.self),
      .field("id", HackersPub.ID.self),
      .field("name", String?.self),
      .field("published", HackersPub.DateTime.self),
      .field("summary", String?.self),
      .field("content", HackersPub.HTML.self),
      .field("excerpt", String.self),
      .field("url", HackersPub.URL?.self),
      .field("iri", HackersPub.URL.self),
      .field("viewerHasShared", Bool.self),
      .field("viewerHasBookmarked", Bool.self),
      .field("actor", Actor.self),
      .field("media", [Medium].self),
      .field("sharedPost", SharedPost?.self),
      .field("quotedPost", QuotedPost?.self),
      .field("engagementStats", EngagementStats.self),
      .field("reactionGroups", [ReactionGroup].self),
      .field("mentions", Mentions.self, arguments: ["first": 20]),
    ] }
    @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
      ProfilePostFields.self
    ] }

    public var id: HackersPub.ID { __data["id"] }
    public var name: String? { __data["name"] }
    public var published: HackersPub.DateTime { __data["published"] }
    public var summary: String? { __data["summary"] }
    public var content: HackersPub.HTML { __data["content"] }
    public var excerpt: String { __data["excerpt"] }
    public var url: HackersPub.URL? { __data["url"] }
    public var iri: HackersPub.URL { __data["iri"] }
    public var viewerHasShared: Bool { __data["viewerHasShared"] }
    public var viewerHasBookmarked: Bool { __data["viewerHasBookmarked"] }
    public var actor: Actor { __data["actor"] }
    public var media: [Medium] { __data["media"] }
    public var sharedPost: SharedPost? { __data["sharedPost"] }
    public var quotedPost: QuotedPost? { __data["quotedPost"] }
    public var engagementStats: EngagementStats { __data["engagementStats"] }
    public var reactionGroups: [ReactionGroup] { __data["reactionGroups"] }
    public var mentions: Mentions { __data["mentions"] }

    /// Actor
    ///
    /// Parent Type: `Actor`
    public struct Actor: HackersPub.SelectionSet {
      @_spi(Unsafe) public let __data: DataDict
      @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

      @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Actor }
      @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
        .field("__typename", String.self),
        .field("id", HackersPub.ID.self),
        .field("name", HackersPub.HTML?.self),
        .field("handle", String.self),
        .field("avatarUrl", HackersPub.URL.self),
      ] }
      @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
        ProfilePostFields.Actor.self
      ] }

      public var id: HackersPub.ID { __data["id"] }
      public var name: HackersPub.HTML? { __data["name"] }
      public var handle: String { __data["handle"] }
      public var avatarUrl: HackersPub.URL { __data["avatarUrl"] }
    }

    /// Medium
    ///
    /// Parent Type: `PostMedium`
    public struct Medium: HackersPub.SelectionSet {
      @_spi(Unsafe) public let __data: DataDict
      @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

      @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.PostMedium }
      @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
        .field("__typename", String.self),
        .field("url", HackersPub.URL.self),
        .field("thumbnailUrl", String?.self),
        .field("alt", String?.self),
        .field("height", Int?.self),
        .field("width", Int?.self),
      ] }
      @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
        ProfilePostFields.Medium.self
      ] }

      public var url: HackersPub.URL { __data["url"] }
      public var thumbnailUrl: String? { __data["thumbnailUrl"] }
      public var alt: String? { __data["alt"] }
      public var height: Int? { __data["height"] }
      public var width: Int? { __data["width"] }
    }

    /// SharedPost
    ///
    /// Parent Type: `Post`
    public struct SharedPost: HackersPub.SelectionSet {
      @_spi(Unsafe) public let __data: DataDict
      @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

      @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Interfaces.Post }
      @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
        .field("__typename", String.self),
        .field("id", HackersPub.ID.self),
        .field("name", String?.self),
        .field("published", HackersPub.DateTime.self),
        .field("summary", String?.self),
        .field("content", HackersPub.HTML.self),
        .field("excerpt", String.self),
        .field("url", HackersPub.URL?.self),
        .field("iri", HackersPub.URL.self),
        .field("viewerHasShared", Bool.self),
        .field("viewerHasBookmarked", Bool.self),
        .field("actor", Actor.self),
        .field("media", [Medium].self),
        .field("engagementStats", EngagementStats.self),
        .field("mentions", Mentions.self, arguments: ["first": 20]),
      ] }
      @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
        ProfilePostFields.SharedPost.self
      ] }

      public var id: HackersPub.ID { __data["id"] }
      public var name: String? { __data["name"] }
      public var published: HackersPub.DateTime { __data["published"] }
      public var summary: String? { __data["summary"] }
      public var content: HackersPub.HTML { __data["content"] }
      public var excerpt: String { __data["excerpt"] }
      public var url: HackersPub.URL? { __data["url"] }
      public var iri: HackersPub.URL { __data["iri"] }
      public var viewerHasShared: Bool { __data["viewerHasShared"] }
      public var viewerHasBookmarked: Bool { __data["viewerHasBookmarked"] }
      public var actor: Actor { __data["actor"] }
      public var media: [Medium] { __data["media"] }
      public var engagementStats: EngagementStats { __data["engagementStats"] }
      public var mentions: Mentions { __data["mentions"] }

      /// SharedPost.Actor
      ///
      /// Parent Type: `Actor`
      public struct Actor: HackersPub.SelectionSet {
        @_spi(Unsafe) public let __data: DataDict
        @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

        @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Actor }
        @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .field("id", HackersPub.ID.self),
          .field("name", HackersPub.HTML?.self),
          .field("handle", String.self),
          .field("avatarUrl", HackersPub.URL.self),
        ] }
        @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
          ProfilePostFields.SharedPost.Actor.self
        ] }

        public var id: HackersPub.ID { __data["id"] }
        public var name: HackersPub.HTML? { __data["name"] }
        public var handle: String { __data["handle"] }
        public var avatarUrl: HackersPub.URL { __data["avatarUrl"] }
      }

      /// SharedPost.Medium
      ///
      /// Parent Type: `PostMedium`
      public struct Medium: HackersPub.SelectionSet {
        @_spi(Unsafe) public let __data: DataDict
        @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

        @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.PostMedium }
        @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .field("url", HackersPub.URL.self),
          .field("thumbnailUrl", String?.self),
          .field("alt", String?.self),
          .field("height", Int?.self),
          .field("width", Int?.self),
        ] }
        @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
          ProfilePostFields.SharedPost.Medium.self
        ] }

        public var url: HackersPub.URL { __data["url"] }
        public var thumbnailUrl: String? { __data["thumbnailUrl"] }
        public var alt: String? { __data["alt"] }
        public var height: Int? { __data["height"] }
        public var width: Int? { __data["width"] }
      }

      /// SharedPost.EngagementStats
      ///
      /// Parent Type: `PostEngagementStats`
      public struct EngagementStats: HackersPub.SelectionSet {
        @_spi(Unsafe) public let __data: DataDict
        @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

        @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.PostEngagementStats }
        @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .field("replies", Int.self),
          .field("reactions", Int.self),
          .field("shares", Int.self),
          .field("quotes", Int.self),
        ] }
        @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
          ProfilePostFields.SharedPost.EngagementStats.self
        ] }

        public var replies: Int { __data["replies"] }
        public var reactions: Int { __data["reactions"] }
        public var shares: Int { __data["shares"] }
        public var quotes: Int { __data["quotes"] }
      }

      /// SharedPost.Mentions
      ///
      /// Parent Type: `PostMentionsConnection`
      public struct Mentions: HackersPub.SelectionSet {
        @_spi(Unsafe) public let __data: DataDict
        @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

        @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.PostMentionsConnection }
        @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .field("edges", [Edge].self),
        ] }
        @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
          ProfilePostFields.SharedPost.Mentions.self
        ] }

        public var edges: [Edge] { __data["edges"] }

        /// SharedPost.Mentions.Edge
        ///
        /// Parent Type: `PostMentionsConnectionEdge`
        public struct Edge: HackersPub.SelectionSet {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.PostMentionsConnectionEdge }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("__typename", String.self),
            .field("node", Node.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            ProfilePostFields.SharedPost.Mentions.Edge.self
          ] }

          public var node: Node { __data["node"] }

          /// SharedPost.Mentions.Edge.Node
          ///
          /// Parent Type: `Actor`
          public struct Node: HackersPub.SelectionSet {
            @_spi(Unsafe) public let __data: DataDict
            @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

            @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Actor }
            @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
              .field("__typename", String.self),
              .field("handle", String.self),
            ] }
            @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
              ProfilePostFields.SharedPost.Mentions.Edge.Node.self
            ] }

            public var handle: String { __data["handle"] }
          }
        }
      }
    }

    /// QuotedPost
    ///
    /// Parent Type: `Post`
    public struct QuotedPost: HackersPub.SelectionSet {
      @_spi(Unsafe) public let __data: DataDict
      @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

      @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Interfaces.Post }
      @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
        .field("__typename", String.self),
        .field("id", HackersPub.ID.self),
        .field("name", String?.self),
        .field("published", HackersPub.DateTime.self),
        .field("summary", String?.self),
        .field("content", HackersPub.HTML.self),
        .field("excerpt", String.self),
        .field("url", HackersPub.URL?.self),
        .field("iri", HackersPub.URL.self),
        .field("actor", Actor.self),
        .field("media", [Medium].self),
      ] }
      @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
        ProfilePostFields.QuotedPost.self
      ] }

      public var id: HackersPub.ID { __data["id"] }
      public var name: String? { __data["name"] }
      public var published: HackersPub.DateTime { __data["published"] }
      public var summary: String? { __data["summary"] }
      public var content: HackersPub.HTML { __data["content"] }
      public var excerpt: String { __data["excerpt"] }
      public var url: HackersPub.URL? { __data["url"] }
      public var iri: HackersPub.URL { __data["iri"] }
      public var actor: Actor { __data["actor"] }
      public var media: [Medium] { __data["media"] }

      /// QuotedPost.Actor
      ///
      /// Parent Type: `Actor`
      public struct Actor: HackersPub.SelectionSet {
        @_spi(Unsafe) public let __data: DataDict
        @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

        @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Actor }
        @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .field("id", HackersPub.ID.self),
          .field("name", HackersPub.HTML?.self),
          .field("handle", String.self),
          .field("avatarUrl", HackersPub.URL.self),
        ] }
        @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
          ProfilePostFields.QuotedPost.Actor.self
        ] }

        public var id: HackersPub.ID { __data["id"] }
        public var name: HackersPub.HTML? { __data["name"] }
        public var handle: String { __data["handle"] }
        public var avatarUrl: HackersPub.URL { __data["avatarUrl"] }
      }

      /// QuotedPost.Medium
      ///
      /// Parent Type: `PostMedium`
      public struct Medium: HackersPub.SelectionSet {
        @_spi(Unsafe) public let __data: DataDict
        @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

        @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.PostMedium }
        @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .field("url", HackersPub.URL.self),
          .field("thumbnailUrl", String?.self),
          .field("alt", String?.self),
          .field("height", Int?.self),
          .field("width", Int?.self),
        ] }
        @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
          ProfilePostFields.QuotedPost.Medium.self
        ] }

        public var url: HackersPub.URL { __data["url"] }
        public var thumbnailUrl: String? { __data["thumbnailUrl"] }
        public var alt: String? { __data["alt"] }
        public var height: Int? { __data["height"] }
        public var width: Int? { __data["width"] }
      }
    }

    /// EngagementStats
    ///
    /// Parent Type: `PostEngagementStats`
    public struct EngagementStats: HackersPub.SelectionSet {
      @_spi(Unsafe) public let __data: DataDict
      @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

      @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.PostEngagementStats }
      @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
        .field("__typename", String.self),
        .field("replies", Int.self),
        .field("reactions", Int.self),
        .field("shares", Int.self),
        .field("quotes", Int.self),
      ] }
      @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
        ProfilePostFields.EngagementStats.self
      ] }

      public var replies: Int { __data["replies"] }
      public var reactions: Int { __data["reactions"] }
      public var shares: Int { __data["shares"] }
      public var quotes: Int { __data["quotes"] }
    }

    /// ReactionGroup
    ///
    /// Parent Type: `ReactionGroup`
    public struct ReactionGroup: HackersPub.SelectionSet {
      @_spi(Unsafe) public let __data: DataDict
      @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

      @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Interfaces.ReactionGroup }
      @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
        .field("__typename", String.self),
        .inlineFragment(AsEmojiReactionGroup.self),
        .inlineFragment(AsCustomEmojiReactionGroup.self),
      ] }
      @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
        ProfilePostFields.ReactionGroup.self
      ] }

      public var asEmojiReactionGroup: AsEmojiReactionGroup? { _asInlineFragment() }
      public var asCustomEmojiReactionGroup: AsCustomEmojiReactionGroup? { _asInlineFragment() }

      /// ReactionGroup.AsEmojiReactionGroup
      ///
      /// Parent Type: `EmojiReactionGroup`
      public struct AsEmojiReactionGroup: HackersPub.InlineFragment {
        @_spi(Unsafe) public let __data: DataDict
        @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

        public typealias RootEntityType = ProfilePostFields.ReactionGroup
        @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.EmojiReactionGroup }
        @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
          .field("emoji", String.self),
          .field("reactors", Reactors.self),
        ] }
        @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
          ProfilePostFields.ReactionGroup.self,
          ProfilePostFields.ReactionGroup.AsEmojiReactionGroup.self
        ] }

        public var emoji: String { __data["emoji"] }
        public var reactors: Reactors { __data["reactors"] }

        /// ReactionGroup.AsEmojiReactionGroup.Reactors
        ///
        /// Parent Type: `ReactionGroupReactorsConnection`
        public struct Reactors: HackersPub.SelectionSet {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.ReactionGroupReactorsConnection }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("__typename", String.self),
            .field("totalCount", Int.self),
            .field("viewerHasReacted", Bool.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            ProfilePostFields.ReactionGroup.AsEmojiReactionGroup.Reactors.self
          ] }

          public var totalCount: Int { __data["totalCount"] }
          public var viewerHasReacted: Bool { __data["viewerHasReacted"] }
        }
      }

      /// ReactionGroup.AsCustomEmojiReactionGroup
      ///
      /// Parent Type: `CustomEmojiReactionGroup`
      public struct AsCustomEmojiReactionGroup: HackersPub.InlineFragment {
        @_spi(Unsafe) public let __data: DataDict
        @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

        public typealias RootEntityType = ProfilePostFields.ReactionGroup
        @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.CustomEmojiReactionGroup }
        @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
          .field("customEmoji", CustomEmoji.self),
          .field("reactors", Reactors.self),
        ] }
        @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
          ProfilePostFields.ReactionGroup.self,
          ProfilePostFields.ReactionGroup.AsCustomEmojiReactionGroup.self
        ] }

        public var customEmoji: CustomEmoji { __data["customEmoji"] }
        public var reactors: Reactors { __data["reactors"] }

        /// ReactionGroup.AsCustomEmojiReactionGroup.CustomEmoji
        ///
        /// Parent Type: `CustomEmoji`
        public struct CustomEmoji: HackersPub.SelectionSet {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.CustomEmoji }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("__typename", String.self),
            .field("id", HackersPub.ID.self),
            .field("name", String.self),
            .field("imageUrl", String.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            ProfilePostFields.ReactionGroup.AsCustomEmojiReactionGroup.CustomEmoji.self
          ] }

          public var id: HackersPub.ID { __data["id"] }
          public var name: String { __data["name"] }
          public var imageUrl: String { __data["imageUrl"] }
        }

        /// ReactionGroup.AsCustomEmojiReactionGroup.Reactors
        ///
        /// Parent Type: `ReactionGroupReactorsConnection`
        public struct Reactors: HackersPub.SelectionSet {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.ReactionGroupReactorsConnection }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("__typename", String.self),
            .field("totalCount", Int.self),
            .field("viewerHasReacted", Bool.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            ProfilePostFields.ReactionGroup.AsCustomEmojiReactionGroup.Reactors.self
          ] }

          public var totalCount: Int { __data["totalCount"] }
          public var viewerHasReacted: Bool { __data["viewerHasReacted"] }
        }
      }
    }

    /// Mentions
    ///
    /// Parent Type: `PostMentionsConnection`
    public struct Mentions: HackersPub.SelectionSet {
      @_spi(Unsafe) public let __data: DataDict
      @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

      @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.PostMentionsConnection }
      @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
        .field("__typename", String.self),
        .field("edges", [Edge].self),
      ] }
      @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
        ProfilePostFields.Mentions.self
      ] }

      public var edges: [Edge] { __data["edges"] }

      /// Mentions.Edge
      ///
      /// Parent Type: `PostMentionsConnectionEdge`
      public struct Edge: HackersPub.SelectionSet {
        @_spi(Unsafe) public let __data: DataDict
        @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

        @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.PostMentionsConnectionEdge }
        @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .field("node", Node.self),
        ] }
        @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
          ProfilePostFields.Mentions.Edge.self
        ] }

        public var node: Node { __data["node"] }

        /// Mentions.Edge.Node
        ///
        /// Parent Type: `Actor`
        public struct Node: HackersPub.SelectionSet {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Actor }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("__typename", String.self),
            .field("id", HackersPub.ID.self),
            .field("handle", String.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            ProfilePostFields.Mentions.Edge.Node.self
          ] }

          public var id: HackersPub.ID { __data["id"] }
          public var handle: String { __data["handle"] }
        }
      }
    }
  }

}