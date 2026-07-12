@testable import HackersPub
import Testing

struct SharedPostQuoteConformanceTests {
    @Test func postDetailSharedCardBuildsACompleteQuotePresentation() throws {
        let quote = StubQuotedPost(
            id: "quote-42",
            name: "Quoted title",
            published: "2026-07-12T10:30:00Z",
            content: "<p>Quoted body</p>",
            actor: StubActor(
                id: "actor-7",
                name: "Quoted author",
                handle: "@quoted@example.com",
                avatarUrl: "https://example.com/avatar.png"
            ),
            media: [
                StubMedium(
                    url: "https://example.com/image.png",
                    thumbnailUrl: "https://example.com/thumb.png",
                    alt: "description",
                    width: 640,
                    height: 480
                )
            ]
        )
        let sharedPost = StubPost(quotedPost: quote)

        let presentation = try #require(PostDetailQuotePresentation(sharedPost: sharedPost))

        #expect(presentation.id == quote.id)
        #expect(presentation.navigationPostID == quote.id)
        #expect(presentation.name == quote.name)
        #expect(presentation.content == quote.content)
        #expect(presentation.published == quote.published)
        #expect(presentation.actor.id == quote.actor.id)
        #expect(presentation.actor.name == quote.actor.name)
        #expect(presentation.actor.handle == quote.actor.handle)
        #expect(presentation.actor.avatarUrl == quote.actor.avatarUrl)
        #expect(presentation.media.count == 1)
        #expect(presentation.media[0].url == quote.media[0].url)
        #expect(presentation.media[0].thumbnailUrl == quote.media[0].thumbnailUrl)
        #expect(presentation.media[0].alt == quote.media[0].alt)
        #expect(presentation.media[0].width == quote.media[0].width)
        #expect(presentation.media[0].height == quote.media[0].height)
    }

    @Test func sharedPostSelectionsExposeOneLevelQuoteCards() {
        requireQuoteCard(
            HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge.Node.SharedPost.self,
            quote: HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge.Node.SharedPost.QuotedPost.self
        )
        requireQuoteCard(
            HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge.Node.SharedPost.self,
            quote: HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge.Node.SharedPost.QuotedPost.self
        )
        requireQuoteCard(
            HackersPub.PersonalTimelineQuery.Data.PersonalTimeline.Edge.Node.SharedPost.self,
            quote: HackersPub.PersonalTimelineQuery.Data.PersonalTimeline.Edge.Node.SharedPost.QuotedPost.self
        )
        requireQuoteCard(
            HackersPub.SearchPostQuery.Data.SearchPost.Edge.Node.SharedPost.self,
            quote: HackersPub.SearchPostQuery.Data.SearchPost.Edge.Node.SharedPost.QuotedPost.self
        )
        requireQuoteCard(
            HackersPub.ActorByHandleQuery.Data.ActorByHandle.Posts.Edge.Node.SharedPost.self,
            quote: HackersPub.ActorByHandleQuery.Data.ActorByHandle.Posts.Edge.Node.SharedPost.QuotedPost.self
        )
        requireQuoteCard(
            HackersPub.ProfilePostFields.SharedPost.self,
            quote: HackersPub.ProfilePostFields.SharedPost.QuotedPost.self
        )
        requireQuoteCard(
            HackersPub.PostDetailQuery.Data.Node.AsPost.SharedPost.self,
            quote: HackersPub.PostDetailQuery.Data.Node.AsPost.SharedPost.QuotedPost.self
        )
        requireQuoteCard(
            HackersPub.PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.SharedPost.self,
            quote: HackersPub.PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.SharedPost.QuotedPost.self
        )
        requireQuoteCard(
            HackersPub.PostQuotesQuery.Data.Node.AsPost.Quotes.Edge.Node.SharedPost.self,
            quote: HackersPub.PostQuotesQuery.Data.Node.AsPost.Quotes.Edge.Node.SharedPost.QuotedPost.self
        )
    }

    private func requireQuoteCard<P: PostProtocol, Q: QuotedPostProtocol>(
        _: P.Type,
        quote _: Q.Type
    ) where P.QuotedPostType == Q {}
}

private struct StubActor: ActorProtocol, Equatable {
    let id: String
    let name: String?
    let handle: String
    let avatarUrl: String
}

private struct StubMedium: MediaProtocol, Equatable {
    let url: String
    let thumbnailUrl: String?
    let alt: String?
    let width: Int?
    let height: Int?
}

private struct StubQuotedPost: QuotedPostProtocol, Equatable {
    let id: String
    let name: String?
    let published: String
    let content: String
    let actor: StubActor
    let media: [StubMedium]
}

private struct StubEngagementStats: EngagementStatsProtocol {
    let replies = 0
    let reactions = 0
    let shares = 0
    let quotes = 0
}

private final class StubPost: PostProtocol {
    let id = "shared-1"
    let name: String? = nil
    let published = "2026-07-12T10:00:00Z"
    let content = "<p>Shared body</p>"
    let actor = StubActor(id: "shared-actor", name: nil, handle: "@shared@example.com", avatarUrl: "")
    let media: [StubMedium] = []
    let summary: String? = nil
    let excerpt = "Shared body"
    let url: String? = nil
    let iri = "https://example.com/shared-1"
    let sharedPost: StubPost? = nil
    let quotedPost: StubQuotedPost?
    let engagementStats = StubEngagementStats()
    let viewerHasShared = false
    let viewerHasBookmarked = false
    let mentionedHandles: [String] = []
    let isArticle = false

    init(quotedPost: StubQuotedPost?) {
        self.quotedPost = quotedPost
    }
}
