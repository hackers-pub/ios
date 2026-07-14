// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI
@_spi(Execution) @_spi(Unsafe) import ApolloAPI

public extension HackersPub {
  struct ActorNotesQuery: GraphQLQuery {
    public static let operationName: String = "ActorNotesQuery"
    public static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"query ActorNotesQuery($handle: String!, $after: String, $before: String, $first: Int, $last: Int) { actorByHandle(handle: $handle, allowLocalHandle: true) { __typename id notes(first: $first, after: $after, before: $before, last: $last) { __typename edges { __typename cursor node { __typename ...ProfilePostFields } } pageInfo { __typename hasPreviousPage hasNextPage startCursor endCursor } } } }"#,
        fragments: [ProfilePostFields.self]
      ))

    public var handle: String
    public var after: GraphQLNullable<String>
    public var before: GraphQLNullable<String>
    public var first: GraphQLNullable<Int32>
    public var last: GraphQLNullable<Int32>

    public init(
      handle: String,
      after: GraphQLNullable<String>,
      before: GraphQLNullable<String>,
      first: GraphQLNullable<Int32>,
      last: GraphQLNullable<Int32>
    ) {
      self.handle = handle
      self.after = after
      self.before = before
      self.first = first
      self.last = last
    }

    @_spi(Unsafe) public var __variables: Variables? { [
      "handle": handle,
      "after": after,
      "before": before,
      "first": first,
      "last": last
    ] }

    public struct Data: HackersPub.SelectionSet {
      @_spi(Unsafe) public let __data: DataDict
      @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

      @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Query }
      @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
        .field("actorByHandle", ActorByHandle?.self, arguments: [
          "handle": .variable("handle"),
          "allowLocalHandle": true
        ]),
      ] }
      @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
        ActorNotesQuery.Data.self
      ] }

      /// Look up an actor by their fediverse handle (e.g., `@alice@mastodon.social` or `alice@hackers.pub`). For `user@host` handles not already in the local cache, triggers an outbound WebFinger + ActivityPub fetch and persists the result; this only happens for authenticated requests, since unauthenticated callers are not allowed to spawn outbound federation lookups.
      public var actorByHandle: ActorByHandle? { __data["actorByHandle"] }

      /// ActorByHandle
      ///
      /// Parent Type: `Actor`
      public struct ActorByHandle: HackersPub.SelectionSet {
        @_spi(Unsafe) public let __data: DataDict
        @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

        @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Actor }
        @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .field("id", HackersPub.ID.self),
          .field("notes", Notes.self, arguments: [
            "first": .variable("first"),
            "after": .variable("after"),
            "before": .variable("before"),
            "last": .variable("last")
          ]),
        ] }
        @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
          ActorNotesQuery.Data.ActorByHandle.self
        ] }

        public var id: HackersPub.ID { __data["id"] }
        /// This actor's `Note`-type posts, newest first, filtered to those visible to the viewer. Includes both original notes and boost wrappers of remote notes. Use `sharedPosts` to see only boosts. Pass `actingAccountId` for an organization perspective.
        public var notes: Notes { __data["notes"] }

        /// ActorByHandle.Notes
        ///
        /// Parent Type: `ActorNotesConnection`
        public struct Notes: HackersPub.SelectionSet {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.ActorNotesConnection }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("__typename", String.self),
            .field("edges", [Edge].self),
            .field("pageInfo", PageInfo.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            ActorNotesQuery.Data.ActorByHandle.Notes.self
          ] }

          public var edges: [Edge] { __data["edges"] }
          public var pageInfo: PageInfo { __data["pageInfo"] }

          /// ActorByHandle.Notes.Edge
          ///
          /// Parent Type: `ActorNotesConnectionEdge`
          public struct Edge: HackersPub.SelectionSet {
            @_spi(Unsafe) public let __data: DataDict
            @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

            @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.ActorNotesConnectionEdge }
            @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
              .field("__typename", String.self),
              .field("cursor", String.self),
              .field("node", Node.self),
            ] }
            @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
              ActorNotesQuery.Data.ActorByHandle.Notes.Edge.self
            ] }

            public var cursor: String { __data["cursor"] }
            public var node: Node { __data["node"] }

            /// ActorByHandle.Notes.Edge.Node
            ///
            /// Parent Type: `Note`
            public struct Node: HackersPub.SelectionSet {
              @_spi(Unsafe) public let __data: DataDict
              @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

              @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Note }
              @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
                .field("__typename", String.self),
                .fragment(ProfilePostFields.self),
              ] }
              @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                ActorNotesQuery.Data.ActorByHandle.Notes.Edge.Node.self,
                ProfilePostFields.self
              ] }

              public var id: HackersPub.ID { __data["id"] }
              /// The post's title. Non-null for `Article`s and local poll `Question`s; `null` for `Note`s and boost wrappers.  `null` when the post is censored or its author is hidden by a moderation sanction (or it is a boost wrapper of such a post, whose title it copies) and the viewer is neither the content's author nor a moderator.
              public var name: String? { __data["name"] }
              public var published: HackersPub.DateTime { __data["published"] }
              /// Author-provided or LLM-generated summary of the post. `null` when no summary has been set. For LLM summaries, check `ArticleContent.summary` and `summaryStarted` instead, as those are tracked per language on articles.  `null` when the post is censored or its author is hidden by a moderation sanction (or it boosts such a post), and the viewer is neither the content's author nor a moderator.
              public var summary: String? { __data["summary"] }
              /// The post's full HTML content, with custom emoji shortcodes rendered as `<img>` elements and external links annotated with `target="_blank"`. Boost wrappers copy the boosted post's content; prefer `sharedPost.content`.  Empty when the post is censored or its author is hidden by a moderation sanction (or it boosts such a post), and the viewer is neither the content's author nor a moderator.
              public var content: HackersPub.HTML { __data["content"] }
              /// Plain-text excerpt of the post. Returns `summary` when set; otherwise falls back to the HTML content stripped of tags. For a truncated HTML preview, use `excerptHtml` instead.  Empty when the post is censored or its author is hidden by a moderation sanction (or it boosts such a post) and the viewer is neither the content's author nor a moderator.
              public var excerpt: String { __data["excerpt"] }
              /// The canonical, human-readable URL of this post. For source-backed local posts the path encodes the local source identifier: `Note.sourceId` for notes, `Article.publishedYear` + `Article.slug` for articles, and `Question.sourceId` for questions. It does not encode `Post.uuid`. For federated remote posts and local share wrappers (boosts) this is whatever URL the originating instance advertised (copied from the shared post in the boost case) and is unrelated to the wrapper's own row PK. Prefer this field over hand-building a path from `Post.uuid`: `uuid` is the row PK and does not match the path here for source-backed local posts.  `null` when the post is censored or its author is hidden by a moderation sanction, and the viewer is neither the content's author nor a moderator, EXCEPT for a local post (whose own permalink renders the notice): a boost wrapper's URL mirrors the boosted post's, and a remote post's URL points at the uncensored copy on its origin instance, so both are hidden.
              public var url: HackersPub.URL? { __data["url"] }
              /// The post's ActivityPub IRI, used as its canonical identifier in federation. For local posts this is an `/ap/…` endpoint; for remote posts it is whatever IRI the originating instance assigned. Prefer `url` for human-readable links.  When the post is censored or its author is hidden by a moderation sanction, and the viewer is neither the author nor a moderator, a remote IRI (or a boost wrapper's, whose `url` is also nulled) is replaced with the local permalink that renders the notice, so a `url ?? iri` fallback never leaks the uncensored origin. A local non-wrapper post keeps its own `/ap/…` IRI (it does not point outside this instance).
              public var iri: HackersPub.URL { __data["iri"] }
              /// Whether the selected viewer account has boosted this post. Always `false` for unauthenticated requests. Pass `actingAccountId` for an organization perspective.
              public var viewerHasShared: Bool { __data["viewerHasShared"] }
              /// Whether the authenticated viewer has bookmarked this post. Always `false` for unauthenticated requests.
              public var viewerHasBookmarked: Bool { __data["viewerHasBookmarked"] }
              /// The actor who authored or boosted this post.
              public var actor: Actor { __data["actor"] }
              /// Media attachments on this post, in display order. For federated posts the URLs point to the originating instance.  Empty when the post is censored or its author is hidden by a moderation sanction, and the viewer is neither the author nor a moderator: attachments are part of the hidden content.
              public var media: [Medium] { __data["media"] }
              /// The post being boosted. Non-null only for boost wrapper rows. When this is non-null, `content` is empty and `url` mirrors the shared post's URL.  `null` when the boost wrapper itself is censored, or its author is hidden by a moderation sanction, and the viewer is neither the author nor a moderator (what was boosted is the censored content), and also when the boosted post is not visible to the viewer (e.g., a followers-only post the viewer does not follow), so a boost cannot leak its private target.
              public var sharedPost: SharedPost? { __data["sharedPost"] }
              /// The post being quoted inline. `null` for posts that are not quotes, when the quoting post is censored or its author is hidden by a moderation sanction and the viewer is neither its author nor a moderator (the quoted target is part of the censored content), and also when the quoted post is not visible to the viewer (e.g., a followers-only post the viewer does not follow), so a public quote cannot leak its private target.
              public var quotedPost: QuotedPost? { __data["quotedPost"] }
              public var engagementStats: EngagementStats { __data["engagementStats"] }
              public var reactionGroups: [ReactionGroup] { __data["reactionGroups"] }
              /// Actors explicitly @-mentioned in this post. Does not include implicit mentions (e.g., the author of the post being replied to). Empty when the post is censored or its author is hidden by a moderation sanction, and the viewer is neither the author nor a moderator, since the mention targets are part of the censored content.
              public var mentions: Mentions { __data["mentions"] }

              public struct Fragments: FragmentContainer {
                @_spi(Unsafe) public let __data: DataDict
                @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

                public var profilePostFields: ProfilePostFields { _toFragment() }
              }

              public typealias Actor = ProfilePostFields.Actor

              public typealias Medium = ProfilePostFields.Medium

              public typealias SharedPost = ProfilePostFields.SharedPost

              public typealias QuotedPost = ProfilePostFields.QuotedPost

              public typealias EngagementStats = ProfilePostFields.EngagementStats

              public typealias ReactionGroup = ProfilePostFields.ReactionGroup

              public typealias Mentions = ProfilePostFields.Mentions
            }
          }

          /// ActorByHandle.Notes.PageInfo
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
              ActorNotesQuery.Data.ActorByHandle.Notes.PageInfo.self
            ] }

            public var hasPreviousPage: Bool { __data["hasPreviousPage"] }
            public var hasNextPage: Bool { __data["hasNextPage"] }
            public var startCursor: String? { __data["startCursor"] }
            public var endCursor: String? { __data["endCursor"] }
          }
        }
      }
    }
  }

}