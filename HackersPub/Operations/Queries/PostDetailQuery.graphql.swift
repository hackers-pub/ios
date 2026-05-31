// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI
@_spi(Execution) @_spi(Unsafe) import ApolloAPI

public extension HackersPub {
  struct PostDetailQuery: GraphQLQuery {
    public static let operationName: String = "PostDetailQuery"
    public static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"query PostDetailQuery($id: ID!, $repliesAfter: String) { node(id: $id) { __typename ... on Post { __typename id name published summary content excerpt url iri visibility viewerHasShared viewerHasBookmarked actor { __typename id name handle avatarUrl } media { __typename url thumbnailUrl alt height width } replyTarget { __typename id name published summary content excerpt url iri viewerHasShared viewerHasBookmarked actor { __typename id name handle avatarUrl } media { __typename url thumbnailUrl alt height width } engagementStats { __typename replies reactions shares quotes } } sharedPost { __typename id name published summary content excerpt url iri viewerHasShared viewerHasBookmarked actor { __typename id name handle avatarUrl } media { __typename url thumbnailUrl alt height width } mentions(first: 20) { __typename edges { __typename node { __typename handle } } } engagementStats { __typename replies reactions shares quotes } } quotedPost { __typename id name published summary content excerpt url iri actor { __typename id name handle avatarUrl } media { __typename url thumbnailUrl alt height width } } mentions(first: 20) { __typename edges { __typename node { __typename handle } } } engagementStats { __typename replies reactions shares quotes } reactionGroups { __typename ... on EmojiReactionGroup { emoji reactors(first: 20) { __typename edges { __typename node { __typename id name handle avatarUrl } } pageInfo { __typename hasPreviousPage hasNextPage startCursor endCursor } totalCount viewerHasReacted } } ... on CustomEmojiReactionGroup { customEmoji { __typename id name imageUrl } reactors(first: 20) { __typename edges { __typename node { __typename id name handle avatarUrl } } pageInfo { __typename hasPreviousPage hasNextPage startCursor endCursor } totalCount viewerHasReacted } } } replies(first: 20, after: $repliesAfter) { __typename edges { __typename cursor node { __typename id name published summary content excerpt url iri viewerHasShared viewerHasBookmarked actor { __typename id name handle avatarUrl } media { __typename url thumbnailUrl alt height width } sharedPost { __typename id name published summary content excerpt url iri viewerHasShared viewerHasBookmarked actor { __typename id name handle avatarUrl } media { __typename url thumbnailUrl alt height width } mentions(first: 20) { __typename edges { __typename node { __typename handle } } } engagementStats { __typename replies reactions shares quotes } } quotedPost { __typename id name published summary content excerpt url iri actor { __typename id name handle avatarUrl } media { __typename url thumbnailUrl alt height width } } mentions(first: 20) { __typename edges { __typename node { __typename handle } } } engagementStats { __typename replies reactions shares quotes } reactionGroups { __typename ... on EmojiReactionGroup { emoji reactors { __typename totalCount viewerHasReacted } } ... on CustomEmojiReactionGroup { customEmoji { __typename id name imageUrl } reactors { __typename totalCount viewerHasReacted } } } } } pageInfo { __typename hasPreviousPage hasNextPage startCursor endCursor } } } ... on Article { uuid slug language allowLlmTranslation tags contents { __typename id language title content rawContent summary toc url } } } }"#
      ))

    public var id: ID
    public var repliesAfter: GraphQLNullable<String>

    public init(
      id: ID,
      repliesAfter: GraphQLNullable<String>
    ) {
      self.id = id
      self.repliesAfter = repliesAfter
    }

    @_spi(Unsafe) public var __variables: Variables? { [
      "id": id,
      "repliesAfter": repliesAfter
    ] }

    public struct Data: HackersPub.SelectionSet {
      @_spi(Unsafe) public let __data: DataDict
      @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

      @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Query }
      @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
        .field("node", Node?.self, arguments: ["id": .variable("id")]),
      ] }
      @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
        PostDetailQuery.Data.self
      ] }

      public var node: Node? { __data["node"] }

      /// Node
      ///
      /// Parent Type: `Node`
      public struct Node: HackersPub.SelectionSet {
        @_spi(Unsafe) public let __data: DataDict
        @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

        @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Interfaces.Node }
        @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .inlineFragment(AsPost.self),
          .inlineFragment(AsArticle.self),
        ] }
        @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
          PostDetailQuery.Data.Node.self
        ] }

        public var asPost: AsPost? { _asInlineFragment() }
        public var asArticle: AsArticle? { _asInlineFragment() }

        /// Node.AsPost
        ///
        /// Parent Type: `Post`
        public struct AsPost: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = PostDetailQuery.Data.Node
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Interfaces.Post }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("id", HackersPub.ID.self),
            .field("name", String?.self),
            .field("published", HackersPub.DateTime.self),
            .field("summary", String?.self),
            .field("content", HackersPub.HTML.self),
            .field("excerpt", String.self),
            .field("url", HackersPub.URL?.self),
            .field("iri", HackersPub.URL.self),
            .field("visibility", GraphQLEnum<HackersPub.PostVisibility>.self),
            .field("viewerHasShared", Bool.self),
            .field("viewerHasBookmarked", Bool.self),
            .field("actor", Actor.self),
            .field("media", [Medium].self),
            .field("replyTarget", ReplyTarget?.self),
            .field("sharedPost", SharedPost?.self),
            .field("quotedPost", QuotedPost?.self),
            .field("mentions", Mentions.self, arguments: ["first": 20]),
            .field("engagementStats", EngagementStats.self),
            .field("reactionGroups", [ReactionGroup].self),
            .field("replies", Replies.self, arguments: [
              "first": 20,
              "after": .variable("repliesAfter")
            ]),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            PostDetailQuery.Data.Node.self,
            PostDetailQuery.Data.Node.AsPost.self
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
          public var visibility: GraphQLEnum<HackersPub.PostVisibility> { __data["visibility"] }
          /// Whether the authenticated viewer has boosted this post. Always `false` for unauthenticated requests.
          public var viewerHasShared: Bool { __data["viewerHasShared"] }
          /// Whether the authenticated viewer has bookmarked this post. Always `false` for unauthenticated requests.
          public var viewerHasBookmarked: Bool { __data["viewerHasBookmarked"] }
          /// The actor who authored or boosted this post.
          public var actor: Actor { __data["actor"] }
          /// Media attachments on this post, in display order. For federated posts the URLs point to the originating instance.
          public var media: [Medium] { __data["media"] }
          /// The post this post is a reply to, or `null` for top-level posts.
          public var replyTarget: ReplyTarget? { __data["replyTarget"] }
          /// The post being boosted. Non-null only for boost wrapper rows. When this is non-null, `content` is empty and `url` mirrors the shared post's URL.
          public var sharedPost: SharedPost? { __data["sharedPost"] }
          /// The post being quoted inline. `null` for posts that are not quotes.
          public var quotedPost: QuotedPost? { __data["quotedPost"] }
          /// Actors explicitly @-mentioned in this post. Does not include implicit mentions (e.g., the author of the post being replied to).
          public var mentions: Mentions { __data["mentions"] }
          public var engagementStats: EngagementStats { __data["engagementStats"] }
          public var reactionGroups: [ReactionGroup] { __data["reactionGroups"] }
          /// Posts that are direct replies to this post.
          public var replies: Replies { __data["replies"] }

          /// Node.AsPost.Actor
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
              PostDetailQuery.Data.Node.AsPost.Actor.self
            ] }

            public var id: HackersPub.ID { __data["id"] }
            /// The actor's display name rendered as HTML, with custom emoji shortcodes replaced by inline `<img>` elements. `null` when the actor has no display name set.
            public var name: HackersPub.HTML? { __data["name"] }
            /// Full fediverse handle in `@username@host` format, ready to use in @-mentions across the fediverse.
            public var handle: String { __data["handle"] }
            /// URL of the actor's avatar image. Falls back to a Gravatar URL derived from the account's email for local actors without an uploaded avatar.
            public var avatarUrl: HackersPub.URL { __data["avatarUrl"] }
          }

          /// Node.AsPost.Medium
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
              PostDetailQuery.Data.Node.AsPost.Medium.self
            ] }

            public var url: HackersPub.URL { __data["url"] }
            public var thumbnailUrl: String? { __data["thumbnailUrl"] }
            public var alt: String? { __data["alt"] }
            public var height: Int? { __data["height"] }
            public var width: Int? { __data["width"] }
          }

          /// Node.AsPost.ReplyTarget
          ///
          /// Parent Type: `Post`
          public struct ReplyTarget: HackersPub.SelectionSet {
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
            ] }
            @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
              PostDetailQuery.Data.Node.AsPost.ReplyTarget.self
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

            /// Node.AsPost.ReplyTarget.Actor
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
                PostDetailQuery.Data.Node.AsPost.ReplyTarget.Actor.self
              ] }

              public var id: HackersPub.ID { __data["id"] }
              /// The actor's display name rendered as HTML, with custom emoji shortcodes replaced by inline `<img>` elements. `null` when the actor has no display name set.
              public var name: HackersPub.HTML? { __data["name"] }
              /// Full fediverse handle in `@username@host` format, ready to use in @-mentions across the fediverse.
              public var handle: String { __data["handle"] }
              /// URL of the actor's avatar image. Falls back to a Gravatar URL derived from the account's email for local actors without an uploaded avatar.
              public var avatarUrl: HackersPub.URL { __data["avatarUrl"] }
            }

            /// Node.AsPost.ReplyTarget.Medium
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
                PostDetailQuery.Data.Node.AsPost.ReplyTarget.Medium.self
              ] }

              public var url: HackersPub.URL { __data["url"] }
              public var thumbnailUrl: String? { __data["thumbnailUrl"] }
              public var alt: String? { __data["alt"] }
              public var height: Int? { __data["height"] }
              public var width: Int? { __data["width"] }
            }

            /// Node.AsPost.ReplyTarget.EngagementStats
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
                PostDetailQuery.Data.Node.AsPost.ReplyTarget.EngagementStats.self
              ] }

              public var replies: Int { __data["replies"] }
              public var reactions: Int { __data["reactions"] }
              public var shares: Int { __data["shares"] }
              public var quotes: Int { __data["quotes"] }
            }
          }

          /// Node.AsPost.SharedPost
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
              .field("mentions", Mentions.self, arguments: ["first": 20]),
              .field("engagementStats", EngagementStats.self),
            ] }
            @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
              PostDetailQuery.Data.Node.AsPost.SharedPost.self
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
            /// Actors explicitly @-mentioned in this post. Does not include implicit mentions (e.g., the author of the post being replied to).
            public var mentions: Mentions { __data["mentions"] }
            public var engagementStats: EngagementStats { __data["engagementStats"] }

            /// Node.AsPost.SharedPost.Actor
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
                PostDetailQuery.Data.Node.AsPost.SharedPost.Actor.self
              ] }

              public var id: HackersPub.ID { __data["id"] }
              /// The actor's display name rendered as HTML, with custom emoji shortcodes replaced by inline `<img>` elements. `null` when the actor has no display name set.
              public var name: HackersPub.HTML? { __data["name"] }
              /// Full fediverse handle in `@username@host` format, ready to use in @-mentions across the fediverse.
              public var handle: String { __data["handle"] }
              /// URL of the actor's avatar image. Falls back to a Gravatar URL derived from the account's email for local actors without an uploaded avatar.
              public var avatarUrl: HackersPub.URL { __data["avatarUrl"] }
            }

            /// Node.AsPost.SharedPost.Medium
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
                PostDetailQuery.Data.Node.AsPost.SharedPost.Medium.self
              ] }

              public var url: HackersPub.URL { __data["url"] }
              public var thumbnailUrl: String? { __data["thumbnailUrl"] }
              public var alt: String? { __data["alt"] }
              public var height: Int? { __data["height"] }
              public var width: Int? { __data["width"] }
            }

            /// Node.AsPost.SharedPost.Mentions
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
                PostDetailQuery.Data.Node.AsPost.SharedPost.Mentions.self
              ] }

              public var edges: [Edge] { __data["edges"] }

              /// Node.AsPost.SharedPost.Mentions.Edge
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
                  PostDetailQuery.Data.Node.AsPost.SharedPost.Mentions.Edge.self
                ] }

                public var node: Node { __data["node"] }

                /// Node.AsPost.SharedPost.Mentions.Edge.Node
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
                    PostDetailQuery.Data.Node.AsPost.SharedPost.Mentions.Edge.Node.self
                  ] }

                  /// Full fediverse handle in `@username@host` format, ready to use in @-mentions across the fediverse.
                  public var handle: String { __data["handle"] }
                }
              }
            }

            /// Node.AsPost.SharedPost.EngagementStats
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
                PostDetailQuery.Data.Node.AsPost.SharedPost.EngagementStats.self
              ] }

              public var replies: Int { __data["replies"] }
              public var reactions: Int { __data["reactions"] }
              public var shares: Int { __data["shares"] }
              public var quotes: Int { __data["quotes"] }
            }
          }

          /// Node.AsPost.QuotedPost
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
              PostDetailQuery.Data.Node.AsPost.QuotedPost.self
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

            /// Node.AsPost.QuotedPost.Actor
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
                PostDetailQuery.Data.Node.AsPost.QuotedPost.Actor.self
              ] }

              public var id: HackersPub.ID { __data["id"] }
              /// The actor's display name rendered as HTML, with custom emoji shortcodes replaced by inline `<img>` elements. `null` when the actor has no display name set.
              public var name: HackersPub.HTML? { __data["name"] }
              /// Full fediverse handle in `@username@host` format, ready to use in @-mentions across the fediverse.
              public var handle: String { __data["handle"] }
              /// URL of the actor's avatar image. Falls back to a Gravatar URL derived from the account's email for local actors without an uploaded avatar.
              public var avatarUrl: HackersPub.URL { __data["avatarUrl"] }
            }

            /// Node.AsPost.QuotedPost.Medium
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
                PostDetailQuery.Data.Node.AsPost.QuotedPost.Medium.self
              ] }

              public var url: HackersPub.URL { __data["url"] }
              public var thumbnailUrl: String? { __data["thumbnailUrl"] }
              public var alt: String? { __data["alt"] }
              public var height: Int? { __data["height"] }
              public var width: Int? { __data["width"] }
            }
          }

          /// Node.AsPost.Mentions
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
              PostDetailQuery.Data.Node.AsPost.Mentions.self
            ] }

            public var edges: [Edge] { __data["edges"] }

            /// Node.AsPost.Mentions.Edge
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
                PostDetailQuery.Data.Node.AsPost.Mentions.Edge.self
              ] }

              public var node: Node { __data["node"] }

              /// Node.AsPost.Mentions.Edge.Node
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
                  PostDetailQuery.Data.Node.AsPost.Mentions.Edge.Node.self
                ] }

                /// Full fediverse handle in `@username@host` format, ready to use in @-mentions across the fediverse.
                public var handle: String { __data["handle"] }
              }
            }
          }

          /// Node.AsPost.EngagementStats
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
              PostDetailQuery.Data.Node.AsPost.EngagementStats.self
            ] }

            public var replies: Int { __data["replies"] }
            public var reactions: Int { __data["reactions"] }
            public var shares: Int { __data["shares"] }
            public var quotes: Int { __data["quotes"] }
          }

          /// Node.AsPost.ReactionGroup
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
              PostDetailQuery.Data.Node.AsPost.ReactionGroup.self
            ] }

            public var asEmojiReactionGroup: AsEmojiReactionGroup? { _asInlineFragment() }
            public var asCustomEmojiReactionGroup: AsCustomEmojiReactionGroup? { _asInlineFragment() }

            /// Node.AsPost.ReactionGroup.AsEmojiReactionGroup
            ///
            /// Parent Type: `EmojiReactionGroup`
            public struct AsEmojiReactionGroup: HackersPub.InlineFragment {
              @_spi(Unsafe) public let __data: DataDict
              @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

              public typealias RootEntityType = PostDetailQuery.Data.Node.AsPost.ReactionGroup
              @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.EmojiReactionGroup }
              @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
                .field("emoji", String.self),
                .field("reactors", Reactors.self, arguments: ["first": 20]),
              ] }
              @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                PostDetailQuery.Data.Node.AsPost.ReactionGroup.self,
                PostDetailQuery.Data.Node.AsPost.ReactionGroup.AsEmojiReactionGroup.self
              ] }

              public var emoji: String { __data["emoji"] }
              public var reactors: Reactors { __data["reactors"] }

              /// Node.AsPost.ReactionGroup.AsEmojiReactionGroup.Reactors
              ///
              /// Parent Type: `ReactionGroupReactorsConnection`
              public struct Reactors: HackersPub.SelectionSet {
                @_spi(Unsafe) public let __data: DataDict
                @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

                @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.ReactionGroupReactorsConnection }
                @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
                  .field("__typename", String.self),
                  .field("edges", [Edge].self),
                  .field("pageInfo", PageInfo.self),
                  .field("totalCount", Int.self),
                  .field("viewerHasReacted", Bool.self),
                ] }
                @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                  PostDetailQuery.Data.Node.AsPost.ReactionGroup.AsEmojiReactionGroup.Reactors.self
                ] }

                public var edges: [Edge] { __data["edges"] }
                public var pageInfo: PageInfo { __data["pageInfo"] }
                public var totalCount: Int { __data["totalCount"] }
                public var viewerHasReacted: Bool { __data["viewerHasReacted"] }

                /// Node.AsPost.ReactionGroup.AsEmojiReactionGroup.Reactors.Edge
                ///
                /// Parent Type: `ReactionGroupReactorsConnectionEdge`
                public struct Edge: HackersPub.SelectionSet {
                  @_spi(Unsafe) public let __data: DataDict
                  @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

                  @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.ReactionGroupReactorsConnectionEdge }
                  @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
                    .field("__typename", String.self),
                    .field("node", Node.self),
                  ] }
                  @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                    PostDetailQuery.Data.Node.AsPost.ReactionGroup.AsEmojiReactionGroup.Reactors.Edge.self
                  ] }

                  public var node: Node { __data["node"] }

                  /// Node.AsPost.ReactionGroup.AsEmojiReactionGroup.Reactors.Edge.Node
                  ///
                  /// Parent Type: `Actor`
                  public struct Node: HackersPub.SelectionSet {
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
                      PostDetailQuery.Data.Node.AsPost.ReactionGroup.AsEmojiReactionGroup.Reactors.Edge.Node.self
                    ] }

                    public var id: HackersPub.ID { __data["id"] }
                    /// The actor's display name rendered as HTML, with custom emoji shortcodes replaced by inline `<img>` elements. `null` when the actor has no display name set.
                    public var name: HackersPub.HTML? { __data["name"] }
                    /// Full fediverse handle in `@username@host` format, ready to use in @-mentions across the fediverse.
                    public var handle: String { __data["handle"] }
                    /// URL of the actor's avatar image. Falls back to a Gravatar URL derived from the account's email for local actors without an uploaded avatar.
                    public var avatarUrl: HackersPub.URL { __data["avatarUrl"] }
                  }
                }

                /// Node.AsPost.ReactionGroup.AsEmojiReactionGroup.Reactors.PageInfo
                ///
                /// Parent Type: `PageInfo`
                public struct PageInfo: HackersPub.SelectionSet {
                  @_spi(Unsafe) public let __data: DataDict
                  @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

                  @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.PageInfo }
                  @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
                    .field("__typename", String.self),
                    .field("hasPreviousPage", Bool.self),
                    .field("hasNextPage", Bool.self),
                    .field("startCursor", String?.self),
                    .field("endCursor", String?.self),
                  ] }
                  @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                    PostDetailQuery.Data.Node.AsPost.ReactionGroup.AsEmojiReactionGroup.Reactors.PageInfo.self
                  ] }

                  public var hasPreviousPage: Bool { __data["hasPreviousPage"] }
                  public var hasNextPage: Bool { __data["hasNextPage"] }
                  public var startCursor: String? { __data["startCursor"] }
                  public var endCursor: String? { __data["endCursor"] }
                }
              }
            }

            /// Node.AsPost.ReactionGroup.AsCustomEmojiReactionGroup
            ///
            /// Parent Type: `CustomEmojiReactionGroup`
            public struct AsCustomEmojiReactionGroup: HackersPub.InlineFragment {
              @_spi(Unsafe) public let __data: DataDict
              @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

              public typealias RootEntityType = PostDetailQuery.Data.Node.AsPost.ReactionGroup
              @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.CustomEmojiReactionGroup }
              @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
                .field("customEmoji", CustomEmoji.self),
                .field("reactors", Reactors.self, arguments: ["first": 20]),
              ] }
              @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                PostDetailQuery.Data.Node.AsPost.ReactionGroup.self,
                PostDetailQuery.Data.Node.AsPost.ReactionGroup.AsCustomEmojiReactionGroup.self
              ] }

              public var customEmoji: CustomEmoji { __data["customEmoji"] }
              public var reactors: Reactors { __data["reactors"] }

              /// Node.AsPost.ReactionGroup.AsCustomEmojiReactionGroup.CustomEmoji
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
                  PostDetailQuery.Data.Node.AsPost.ReactionGroup.AsCustomEmojiReactionGroup.CustomEmoji.self
                ] }

                public var id: HackersPub.ID { __data["id"] }
                public var name: String { __data["name"] }
                public var imageUrl: String { __data["imageUrl"] }
              }

              /// Node.AsPost.ReactionGroup.AsCustomEmojiReactionGroup.Reactors
              ///
              /// Parent Type: `ReactionGroupReactorsConnection`
              public struct Reactors: HackersPub.SelectionSet {
                @_spi(Unsafe) public let __data: DataDict
                @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

                @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.ReactionGroupReactorsConnection }
                @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
                  .field("__typename", String.self),
                  .field("edges", [Edge].self),
                  .field("pageInfo", PageInfo.self),
                  .field("totalCount", Int.self),
                  .field("viewerHasReacted", Bool.self),
                ] }
                @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                  PostDetailQuery.Data.Node.AsPost.ReactionGroup.AsCustomEmojiReactionGroup.Reactors.self
                ] }

                public var edges: [Edge] { __data["edges"] }
                public var pageInfo: PageInfo { __data["pageInfo"] }
                public var totalCount: Int { __data["totalCount"] }
                public var viewerHasReacted: Bool { __data["viewerHasReacted"] }

                /// Node.AsPost.ReactionGroup.AsCustomEmojiReactionGroup.Reactors.Edge
                ///
                /// Parent Type: `ReactionGroupReactorsConnectionEdge`
                public struct Edge: HackersPub.SelectionSet {
                  @_spi(Unsafe) public let __data: DataDict
                  @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

                  @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.ReactionGroupReactorsConnectionEdge }
                  @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
                    .field("__typename", String.self),
                    .field("node", Node.self),
                  ] }
                  @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                    PostDetailQuery.Data.Node.AsPost.ReactionGroup.AsCustomEmojiReactionGroup.Reactors.Edge.self
                  ] }

                  public var node: Node { __data["node"] }

                  /// Node.AsPost.ReactionGroup.AsCustomEmojiReactionGroup.Reactors.Edge.Node
                  ///
                  /// Parent Type: `Actor`
                  public struct Node: HackersPub.SelectionSet {
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
                      PostDetailQuery.Data.Node.AsPost.ReactionGroup.AsCustomEmojiReactionGroup.Reactors.Edge.Node.self
                    ] }

                    public var id: HackersPub.ID { __data["id"] }
                    /// The actor's display name rendered as HTML, with custom emoji shortcodes replaced by inline `<img>` elements. `null` when the actor has no display name set.
                    public var name: HackersPub.HTML? { __data["name"] }
                    /// Full fediverse handle in `@username@host` format, ready to use in @-mentions across the fediverse.
                    public var handle: String { __data["handle"] }
                    /// URL of the actor's avatar image. Falls back to a Gravatar URL derived from the account's email for local actors without an uploaded avatar.
                    public var avatarUrl: HackersPub.URL { __data["avatarUrl"] }
                  }
                }

                /// Node.AsPost.ReactionGroup.AsCustomEmojiReactionGroup.Reactors.PageInfo
                ///
                /// Parent Type: `PageInfo`
                public struct PageInfo: HackersPub.SelectionSet {
                  @_spi(Unsafe) public let __data: DataDict
                  @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

                  @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.PageInfo }
                  @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
                    .field("__typename", String.self),
                    .field("hasPreviousPage", Bool.self),
                    .field("hasNextPage", Bool.self),
                    .field("startCursor", String?.self),
                    .field("endCursor", String?.self),
                  ] }
                  @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                    PostDetailQuery.Data.Node.AsPost.ReactionGroup.AsCustomEmojiReactionGroup.Reactors.PageInfo.self
                  ] }

                  public var hasPreviousPage: Bool { __data["hasPreviousPage"] }
                  public var hasNextPage: Bool { __data["hasNextPage"] }
                  public var startCursor: String? { __data["startCursor"] }
                  public var endCursor: String? { __data["endCursor"] }
                }
              }
            }
          }

          /// Node.AsPost.Replies
          ///
          /// Parent Type: `PostRepliesConnection`
          public struct Replies: HackersPub.SelectionSet {
            @_spi(Unsafe) public let __data: DataDict
            @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

            @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.PostRepliesConnection }
            @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
              .field("__typename", String.self),
              .field("edges", [Edge].self),
              .field("pageInfo", PageInfo.self),
            ] }
            @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
              PostDetailQuery.Data.Node.AsPost.Replies.self
            ] }

            public var edges: [Edge] { __data["edges"] }
            public var pageInfo: PageInfo { __data["pageInfo"] }

            /// Node.AsPost.Replies.Edge
            ///
            /// Parent Type: `PostRepliesConnectionEdge`
            public struct Edge: HackersPub.SelectionSet {
              @_spi(Unsafe) public let __data: DataDict
              @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

              @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.PostRepliesConnectionEdge }
              @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
                .field("__typename", String.self),
                .field("cursor", String.self),
                .field("node", Node.self),
              ] }
              @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                PostDetailQuery.Data.Node.AsPost.Replies.Edge.self
              ] }

              public var cursor: String { __data["cursor"] }
              public var node: Node { __data["node"] }

              /// Node.AsPost.Replies.Edge.Node
              ///
              /// Parent Type: `Post`
              public struct Node: HackersPub.SelectionSet {
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
                  .field("mentions", Mentions.self, arguments: ["first": 20]),
                  .field("engagementStats", EngagementStats.self),
                  .field("reactionGroups", [ReactionGroup].self),
                ] }
                @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                  PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.self
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
                /// Actors explicitly @-mentioned in this post. Does not include implicit mentions (e.g., the author of the post being replied to).
                public var mentions: Mentions { __data["mentions"] }
                public var engagementStats: EngagementStats { __data["engagementStats"] }
                public var reactionGroups: [ReactionGroup] { __data["reactionGroups"] }

                /// Node.AsPost.Replies.Edge.Node.Actor
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
                    PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.Actor.self
                  ] }

                  public var id: HackersPub.ID { __data["id"] }
                  /// The actor's display name rendered as HTML, with custom emoji shortcodes replaced by inline `<img>` elements. `null` when the actor has no display name set.
                  public var name: HackersPub.HTML? { __data["name"] }
                  /// Full fediverse handle in `@username@host` format, ready to use in @-mentions across the fediverse.
                  public var handle: String { __data["handle"] }
                  /// URL of the actor's avatar image. Falls back to a Gravatar URL derived from the account's email for local actors without an uploaded avatar.
                  public var avatarUrl: HackersPub.URL { __data["avatarUrl"] }
                }

                /// Node.AsPost.Replies.Edge.Node.Medium
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
                    PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.Medium.self
                  ] }

                  public var url: HackersPub.URL { __data["url"] }
                  public var thumbnailUrl: String? { __data["thumbnailUrl"] }
                  public var alt: String? { __data["alt"] }
                  public var height: Int? { __data["height"] }
                  public var width: Int? { __data["width"] }
                }

                /// Node.AsPost.Replies.Edge.Node.SharedPost
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
                    .field("mentions", Mentions.self, arguments: ["first": 20]),
                    .field("engagementStats", EngagementStats.self),
                  ] }
                  @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                    PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.SharedPost.self
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
                  /// Actors explicitly @-mentioned in this post. Does not include implicit mentions (e.g., the author of the post being replied to).
                  public var mentions: Mentions { __data["mentions"] }
                  public var engagementStats: EngagementStats { __data["engagementStats"] }

                  /// Node.AsPost.Replies.Edge.Node.SharedPost.Actor
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
                      PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.SharedPost.Actor.self
                    ] }

                    public var id: HackersPub.ID { __data["id"] }
                    /// The actor's display name rendered as HTML, with custom emoji shortcodes replaced by inline `<img>` elements. `null` when the actor has no display name set.
                    public var name: HackersPub.HTML? { __data["name"] }
                    /// Full fediverse handle in `@username@host` format, ready to use in @-mentions across the fediverse.
                    public var handle: String { __data["handle"] }
                    /// URL of the actor's avatar image. Falls back to a Gravatar URL derived from the account's email for local actors without an uploaded avatar.
                    public var avatarUrl: HackersPub.URL { __data["avatarUrl"] }
                  }

                  /// Node.AsPost.Replies.Edge.Node.SharedPost.Medium
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
                      PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.SharedPost.Medium.self
                    ] }

                    public var url: HackersPub.URL { __data["url"] }
                    public var thumbnailUrl: String? { __data["thumbnailUrl"] }
                    public var alt: String? { __data["alt"] }
                    public var height: Int? { __data["height"] }
                    public var width: Int? { __data["width"] }
                  }

                  /// Node.AsPost.Replies.Edge.Node.SharedPost.Mentions
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
                      PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.SharedPost.Mentions.self
                    ] }

                    public var edges: [Edge] { __data["edges"] }

                    /// Node.AsPost.Replies.Edge.Node.SharedPost.Mentions.Edge
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
                        PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.SharedPost.Mentions.Edge.self
                      ] }

                      public var node: Node { __data["node"] }

                      /// Node.AsPost.Replies.Edge.Node.SharedPost.Mentions.Edge.Node
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
                          PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.SharedPost.Mentions.Edge.Node.self
                        ] }

                        /// Full fediverse handle in `@username@host` format, ready to use in @-mentions across the fediverse.
                        public var handle: String { __data["handle"] }
                      }
                    }
                  }

                  /// Node.AsPost.Replies.Edge.Node.SharedPost.EngagementStats
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
                      PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.SharedPost.EngagementStats.self
                    ] }

                    public var replies: Int { __data["replies"] }
                    public var reactions: Int { __data["reactions"] }
                    public var shares: Int { __data["shares"] }
                    public var quotes: Int { __data["quotes"] }
                  }
                }

                /// Node.AsPost.Replies.Edge.Node.QuotedPost
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
                    PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.QuotedPost.self
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

                  /// Node.AsPost.Replies.Edge.Node.QuotedPost.Actor
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
                      PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.QuotedPost.Actor.self
                    ] }

                    public var id: HackersPub.ID { __data["id"] }
                    /// The actor's display name rendered as HTML, with custom emoji shortcodes replaced by inline `<img>` elements. `null` when the actor has no display name set.
                    public var name: HackersPub.HTML? { __data["name"] }
                    /// Full fediverse handle in `@username@host` format, ready to use in @-mentions across the fediverse.
                    public var handle: String { __data["handle"] }
                    /// URL of the actor's avatar image. Falls back to a Gravatar URL derived from the account's email for local actors without an uploaded avatar.
                    public var avatarUrl: HackersPub.URL { __data["avatarUrl"] }
                  }

                  /// Node.AsPost.Replies.Edge.Node.QuotedPost.Medium
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
                      PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.QuotedPost.Medium.self
                    ] }

                    public var url: HackersPub.URL { __data["url"] }
                    public var thumbnailUrl: String? { __data["thumbnailUrl"] }
                    public var alt: String? { __data["alt"] }
                    public var height: Int? { __data["height"] }
                    public var width: Int? { __data["width"] }
                  }
                }

                /// Node.AsPost.Replies.Edge.Node.Mentions
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
                    PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.Mentions.self
                  ] }

                  public var edges: [Edge] { __data["edges"] }

                  /// Node.AsPost.Replies.Edge.Node.Mentions.Edge
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
                      PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.Mentions.Edge.self
                    ] }

                    public var node: Node { __data["node"] }

                    /// Node.AsPost.Replies.Edge.Node.Mentions.Edge.Node
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
                        PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.Mentions.Edge.Node.self
                      ] }

                      /// Full fediverse handle in `@username@host` format, ready to use in @-mentions across the fediverse.
                      public var handle: String { __data["handle"] }
                    }
                  }
                }

                /// Node.AsPost.Replies.Edge.Node.EngagementStats
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
                    PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.EngagementStats.self
                  ] }

                  public var replies: Int { __data["replies"] }
                  public var reactions: Int { __data["reactions"] }
                  public var shares: Int { __data["shares"] }
                  public var quotes: Int { __data["quotes"] }
                }

                /// Node.AsPost.Replies.Edge.Node.ReactionGroup
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
                    PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.ReactionGroup.self
                  ] }

                  public var asEmojiReactionGroup: AsEmojiReactionGroup? { _asInlineFragment() }
                  public var asCustomEmojiReactionGroup: AsCustomEmojiReactionGroup? { _asInlineFragment() }

                  /// Node.AsPost.Replies.Edge.Node.ReactionGroup.AsEmojiReactionGroup
                  ///
                  /// Parent Type: `EmojiReactionGroup`
                  public struct AsEmojiReactionGroup: HackersPub.InlineFragment {
                    @_spi(Unsafe) public let __data: DataDict
                    @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

                    public typealias RootEntityType = PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.ReactionGroup
                    @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.EmojiReactionGroup }
                    @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
                      .field("emoji", String.self),
                      .field("reactors", Reactors.self),
                    ] }
                    @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                      PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.ReactionGroup.self,
                      PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.ReactionGroup.AsEmojiReactionGroup.self
                    ] }

                    public var emoji: String { __data["emoji"] }
                    public var reactors: Reactors { __data["reactors"] }

                    /// Node.AsPost.Replies.Edge.Node.ReactionGroup.AsEmojiReactionGroup.Reactors
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
                        PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.ReactionGroup.AsEmojiReactionGroup.Reactors.self
                      ] }

                      public var totalCount: Int { __data["totalCount"] }
                      public var viewerHasReacted: Bool { __data["viewerHasReacted"] }
                    }
                  }

                  /// Node.AsPost.Replies.Edge.Node.ReactionGroup.AsCustomEmojiReactionGroup
                  ///
                  /// Parent Type: `CustomEmojiReactionGroup`
                  public struct AsCustomEmojiReactionGroup: HackersPub.InlineFragment {
                    @_spi(Unsafe) public let __data: DataDict
                    @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

                    public typealias RootEntityType = PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.ReactionGroup
                    @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.CustomEmojiReactionGroup }
                    @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
                      .field("customEmoji", CustomEmoji.self),
                      .field("reactors", Reactors.self),
                    ] }
                    @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                      PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.ReactionGroup.self,
                      PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.ReactionGroup.AsCustomEmojiReactionGroup.self
                    ] }

                    public var customEmoji: CustomEmoji { __data["customEmoji"] }
                    public var reactors: Reactors { __data["reactors"] }

                    /// Node.AsPost.Replies.Edge.Node.ReactionGroup.AsCustomEmojiReactionGroup.CustomEmoji
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
                        PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.ReactionGroup.AsCustomEmojiReactionGroup.CustomEmoji.self
                      ] }

                      public var id: HackersPub.ID { __data["id"] }
                      public var name: String { __data["name"] }
                      public var imageUrl: String { __data["imageUrl"] }
                    }

                    /// Node.AsPost.Replies.Edge.Node.ReactionGroup.AsCustomEmojiReactionGroup.Reactors
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
                        PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.ReactionGroup.AsCustomEmojiReactionGroup.Reactors.self
                      ] }

                      public var totalCount: Int { __data["totalCount"] }
                      public var viewerHasReacted: Bool { __data["viewerHasReacted"] }
                    }
                  }
                }
              }
            }

            /// Node.AsPost.Replies.PageInfo
            ///
            /// Parent Type: `PageInfo`
            public struct PageInfo: HackersPub.SelectionSet {
              @_spi(Unsafe) public let __data: DataDict
              @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

              @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.PageInfo }
              @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
                .field("__typename", String.self),
                .field("hasPreviousPage", Bool.self),
                .field("hasNextPage", Bool.self),
                .field("startCursor", String?.self),
                .field("endCursor", String?.self),
              ] }
              @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                PostDetailQuery.Data.Node.AsPost.Replies.PageInfo.self
              ] }

              public var hasPreviousPage: Bool { __data["hasPreviousPage"] }
              public var hasNextPage: Bool { __data["hasNextPage"] }
              public var startCursor: String? { __data["startCursor"] }
              public var endCursor: String? { __data["endCursor"] }
            }
          }
        }

        /// Node.AsArticle
        ///
        /// Parent Type: `Article`
        public struct AsArticle: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = PostDetailQuery.Data.Node
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Article }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("uuid", HackersPub.UUID.self),
            .field("slug", String?.self),
            .field("language", String?.self),
            .field("allowLlmTranslation", Bool?.self),
            .field("tags", [String]?.self),
            .field("contents", [Content].self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            PostDetailQuery.Data.Node.self,
            PostDetailQuery.Data.Node.AsArticle.self,
            PostDetailQuery.Data.Node.AsPost.self
          ] }

          /// The post row's primary key, stable for the lifetime of the post. ⚠️ This is **not** the UUID embedded in `Post.url` for source-backed local posts: local notes that originate here use `Note.sourceId` (= `noteSourceTable.id`) and local articles use `Article.publishedYear` + `Article.slug`. The row PK is the right token whenever there is no local source row — federated remote posts, local share wrappers (boosts, which carry no source and copy the shared post's URL), and Questions (whose originals come only from remote instances and whose local rows exist solely as share wrappers) — and for the internal route that resolves them. `actorByHandle.postByUuid` accepts either the row PK or a source UUID, but resolving by `uuid` for a source-backed local post yields a URL that differs from `Post.url`.
          public var uuid: HackersPub.UUID { __data["uuid"] }
          /// URL slug for the article, used together with `publishedYear` to build its permalink. `null` for remote articles.
          public var slug: String? { __data["slug"] }
          /// BCP 47 language tag of the post's primary content (e.g., `en`, `ja`). `null` when the language is unknown or not specified by the author.
          public var language: String? { __data["language"] }
          /// Whether the author has enabled LLM-based translation for this article. `null` for articles federated from remote instances.
          public var allowLlmTranslation: Bool? { __data["allowLlmTranslation"] }
          /// Author-assigned tags for this article. `null` for articles federated in from remote instances.
          public var tags: [String]? { __data["tags"] }
          /// All available language versions of this article's content. Pass `language` to get only the best-matching locale (BCP 47 negotiation). Pass `includeBeingTranslated: true` to also include language versions whose LLM translation is still in progress.
          public var contents: [Content] { __data["contents"] }
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
          public var visibility: GraphQLEnum<HackersPub.PostVisibility> { __data["visibility"] }
          /// Whether the authenticated viewer has boosted this post. Always `false` for unauthenticated requests.
          public var viewerHasShared: Bool { __data["viewerHasShared"] }
          /// Whether the authenticated viewer has bookmarked this post. Always `false` for unauthenticated requests.
          public var viewerHasBookmarked: Bool { __data["viewerHasBookmarked"] }
          /// The actor who authored or boosted this post.
          public var actor: Actor { __data["actor"] }
          /// Media attachments on this post, in display order. For federated posts the URLs point to the originating instance.
          public var media: [Medium] { __data["media"] }
          /// The post this post is a reply to, or `null` for top-level posts.
          public var replyTarget: ReplyTarget? { __data["replyTarget"] }
          /// The post being boosted. Non-null only for boost wrapper rows. When this is non-null, `content` is empty and `url` mirrors the shared post's URL.
          public var sharedPost: SharedPost? { __data["sharedPost"] }
          /// The post being quoted inline. `null` for posts that are not quotes.
          public var quotedPost: QuotedPost? { __data["quotedPost"] }
          /// Actors explicitly @-mentioned in this post. Does not include implicit mentions (e.g., the author of the post being replied to).
          public var mentions: Mentions { __data["mentions"] }
          public var engagementStats: EngagementStats { __data["engagementStats"] }
          public var reactionGroups: [ReactionGroup] { __data["reactionGroups"] }
          /// Posts that are direct replies to this post.
          public var replies: Replies { __data["replies"] }

          /// Node.AsArticle.Content
          ///
          /// Parent Type: `ArticleContent`
          public struct Content: HackersPub.SelectionSet {
            @_spi(Unsafe) public let __data: DataDict
            @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

            @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.ArticleContent }
            @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
              .field("__typename", String.self),
              .field("id", HackersPub.ID.self),
              .field("language", HackersPub.Locale.self),
              .field("title", String.self),
              .field("content", HackersPub.HTML.self),
              .field("rawContent", HackersPub.Markdown.self),
              .field("summary", String?.self),
              .field("toc", HackersPub.JSON.self),
              .field("url", HackersPub.URL.self),
            ] }
            @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
              PostDetailQuery.Data.Node.AsArticle.Content.self
            ] }

            public var id: HackersPub.ID { __data["id"] }
            /// BCP 47 language tag identifying this content version.
            public var language: HackersPub.Locale { __data["language"] }
            public var title: String { __data["title"] }
            /// Rendered HTML of this language version, with media URLs resolved and external links annotated.
            public var content: HackersPub.HTML { __data["content"] }
            /// The raw markdown content for editing.
            public var rawContent: HackersPub.Markdown { __data["rawContent"] }
            /// LLM-generated summary for this language version. `null` until generation completes. Check `summaryStarted` to distinguish between "not requested" and "in progress".
            public var summary: String? { __data["summary"] }
            /// Table of contents for the article content.
            public var toc: HackersPub.JSON { __data["toc"] }
            /// Canonical URL for this language version. For the article's primary language this is `/@username/year/slug`; for other language versions it appends `/{language}` to that path.
            public var url: HackersPub.URL { __data["url"] }
          }

          public typealias Actor = AsPost.Actor

          public typealias Medium = AsPost.Medium

          public typealias ReplyTarget = AsPost.ReplyTarget

          public typealias SharedPost = AsPost.SharedPost

          public typealias QuotedPost = AsPost.QuotedPost

          public typealias Mentions = AsPost.Mentions

          public typealias EngagementStats = AsPost.EngagementStats

          public typealias ReactionGroup = AsPost.ReactionGroup

          public typealias Replies = AsPost.Replies
        }
      }
    }
  }

}