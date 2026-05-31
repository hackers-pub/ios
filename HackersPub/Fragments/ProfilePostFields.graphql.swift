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
    /// The post's title. Non-null for `Article`s; `null` for `Note`s, boost wrappers, and `Question`s.
    public var name: String? { __data["name"] }
    public var published: HackersPub.DateTime { __data["published"] }
    /// Author-provided or LLM-generated summary of the post. `null` when no summary has been set. For LLM summaries, check `ArticleContent.summary` and `summaryStarted` instead, as those are tracked per language on articles.
    public var summary: String? { __data["summary"] }
    /// The post's full HTML content, with custom emoji shortcodes rendered as `<img>` elements and external links annotated with `target="_blank"`. Boost wrappers have empty content; use `sharedPost.content` instead.
    public var content: HackersPub.HTML { __data["content"] }
    /// Plain-text excerpt of the post. Returns `summary` when set; otherwise falls back to the HTML content stripped of tags. For a truncated HTML preview, use `excerptHtml` instead.
    public var excerpt: String { __data["excerpt"] }
    /// The canonical, human-readable URL of this post. For source-backed local posts the path encodes the local source identifier — `Note.sourceId` for notes, `Article.publishedYear` + `Article.slug` for articles — **not** `Post.uuid`. For federated remote posts and local share wrappers (boosts) this is whatever URL the originating instance advertised — copied from the shared post in the boost case — and is unrelated to the wrapper's own row PK. Prefer this field over hand-building a path from `Post.uuid`: `uuid` is the row PK and does not match the path here for source-backed local posts.
    public var url: HackersPub.URL? { __data["url"] }
    /// The post's ActivityPub IRI, used as its canonical identifier in federation. For local posts this is an `/ap/…` endpoint; for remote posts it is whatever IRI the originating instance assigned. Prefer `url` for human-readable links.
    public var iri: HackersPub.URL { __data["iri"] }
    /// Whether the authenticated viewer has boosted this post. Always `false` for unauthenticated requests.
    public var viewerHasShared: Bool { __data["viewerHasShared"] }
    /// Whether the authenticated viewer has bookmarked this post. Always `false` for unauthenticated requests.
    public var viewerHasBookmarked: Bool { __data["viewerHasBookmarked"] }
    /// The actor who authored or boosted this post.
    public var actor: Actor { __data["actor"] }
    /// Media attachments on this post, in display order. For federated posts the URLs point to the originating instance.
    public var media: [Medium] { __data["media"] }
    /// The post being boosted. Non-null only for boost wrapper rows. When this is non-null, `content` is empty and `url` mirrors the shared post's URL.
    public var sharedPost: SharedPost? { __data["sharedPost"] }
    /// The post being quoted inline. `null` for posts that are not quotes.
    public var quotedPost: QuotedPost? { __data["quotedPost"] }
    public var engagementStats: EngagementStats { __data["engagementStats"] }
    public var reactionGroups: [ReactionGroup] { __data["reactionGroups"] }
    /// Actors explicitly @-mentioned in this post. Does not include implicit mentions (e.g., the author of the post being replied to).
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
      /// The actor's display name rendered as HTML, with custom emoji shortcodes replaced by inline `<img>` elements. `null` when the actor has no display name set.
      public var name: HackersPub.HTML? { __data["name"] }
      /// Full fediverse handle in `@username@host` format, ready to use in @-mentions across the fediverse.
      public var handle: String { __data["handle"] }
      /// URL of the actor's avatar image. Falls back to a Gravatar URL derived from the account's email for local actors without an uploaded avatar.
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
      /// The post's title. Non-null for `Article`s; `null` for `Note`s, boost wrappers, and `Question`s.
      public var name: String? { __data["name"] }
      public var published: HackersPub.DateTime { __data["published"] }
      /// Author-provided or LLM-generated summary of the post. `null` when no summary has been set. For LLM summaries, check `ArticleContent.summary` and `summaryStarted` instead, as those are tracked per language on articles.
      public var summary: String? { __data["summary"] }
      /// The post's full HTML content, with custom emoji shortcodes rendered as `<img>` elements and external links annotated with `target="_blank"`. Boost wrappers have empty content; use `sharedPost.content` instead.
      public var content: HackersPub.HTML { __data["content"] }
      /// Plain-text excerpt of the post. Returns `summary` when set; otherwise falls back to the HTML content stripped of tags. For a truncated HTML preview, use `excerptHtml` instead.
      public var excerpt: String { __data["excerpt"] }
      /// The canonical, human-readable URL of this post. For source-backed local posts the path encodes the local source identifier — `Note.sourceId` for notes, `Article.publishedYear` + `Article.slug` for articles — **not** `Post.uuid`. For federated remote posts and local share wrappers (boosts) this is whatever URL the originating instance advertised — copied from the shared post in the boost case — and is unrelated to the wrapper's own row PK. Prefer this field over hand-building a path from `Post.uuid`: `uuid` is the row PK and does not match the path here for source-backed local posts.
      public var url: HackersPub.URL? { __data["url"] }
      /// The post's ActivityPub IRI, used as its canonical identifier in federation. For local posts this is an `/ap/…` endpoint; for remote posts it is whatever IRI the originating instance assigned. Prefer `url` for human-readable links.
      public var iri: HackersPub.URL { __data["iri"] }
      /// Whether the authenticated viewer has boosted this post. Always `false` for unauthenticated requests.
      public var viewerHasShared: Bool { __data["viewerHasShared"] }
      /// Whether the authenticated viewer has bookmarked this post. Always `false` for unauthenticated requests.
      public var viewerHasBookmarked: Bool { __data["viewerHasBookmarked"] }
      /// The actor who authored or boosted this post.
      public var actor: Actor { __data["actor"] }
      /// Media attachments on this post, in display order. For federated posts the URLs point to the originating instance.
      public var media: [Medium] { __data["media"] }
      public var engagementStats: EngagementStats { __data["engagementStats"] }
      /// Actors explicitly @-mentioned in this post. Does not include implicit mentions (e.g., the author of the post being replied to).
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
        /// The actor's display name rendered as HTML, with custom emoji shortcodes replaced by inline `<img>` elements. `null` when the actor has no display name set.
        public var name: HackersPub.HTML? { __data["name"] }
        /// Full fediverse handle in `@username@host` format, ready to use in @-mentions across the fediverse.
        public var handle: String { __data["handle"] }
        /// URL of the actor's avatar image. Falls back to a Gravatar URL derived from the account's email for local actors without an uploaded avatar.
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

            /// Full fediverse handle in `@username@host` format, ready to use in @-mentions across the fediverse.
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
      /// The post's title. Non-null for `Article`s; `null` for `Note`s, boost wrappers, and `Question`s.
      public var name: String? { __data["name"] }
      public var published: HackersPub.DateTime { __data["published"] }
      /// Author-provided or LLM-generated summary of the post. `null` when no summary has been set. For LLM summaries, check `ArticleContent.summary` and `summaryStarted` instead, as those are tracked per language on articles.
      public var summary: String? { __data["summary"] }
      /// The post's full HTML content, with custom emoji shortcodes rendered as `<img>` elements and external links annotated with `target="_blank"`. Boost wrappers have empty content; use `sharedPost.content` instead.
      public var content: HackersPub.HTML { __data["content"] }
      /// Plain-text excerpt of the post. Returns `summary` when set; otherwise falls back to the HTML content stripped of tags. For a truncated HTML preview, use `excerptHtml` instead.
      public var excerpt: String { __data["excerpt"] }
      /// The canonical, human-readable URL of this post. For source-backed local posts the path encodes the local source identifier — `Note.sourceId` for notes, `Article.publishedYear` + `Article.slug` for articles — **not** `Post.uuid`. For federated remote posts and local share wrappers (boosts) this is whatever URL the originating instance advertised — copied from the shared post in the boost case — and is unrelated to the wrapper's own row PK. Prefer this field over hand-building a path from `Post.uuid`: `uuid` is the row PK and does not match the path here for source-backed local posts.
      public var url: HackersPub.URL? { __data["url"] }
      /// The post's ActivityPub IRI, used as its canonical identifier in federation. For local posts this is an `/ap/…` endpoint; for remote posts it is whatever IRI the originating instance assigned. Prefer `url` for human-readable links.
      public var iri: HackersPub.URL { __data["iri"] }
      /// The actor who authored or boosted this post.
      public var actor: Actor { __data["actor"] }
      /// Media attachments on this post, in display order. For federated posts the URLs point to the originating instance.
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
        /// The actor's display name rendered as HTML, with custom emoji shortcodes replaced by inline `<img>` elements. `null` when the actor has no display name set.
        public var name: HackersPub.HTML? { __data["name"] }
        /// Full fediverse handle in `@username@host` format, ready to use in @-mentions across the fediverse.
        public var handle: String { __data["handle"] }
        /// URL of the actor's avatar image. Falls back to a Gravatar URL derived from the account's email for local actors without an uploaded avatar.
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
          /// Full fediverse handle in `@username@host` format, ready to use in @-mentions across the fediverse.
          public var handle: String { __data["handle"] }
        }
      }
    }
  }

}