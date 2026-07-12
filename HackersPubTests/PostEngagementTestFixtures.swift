@testable import HackersPub

struct StubPostEngagementStats: EngagementStatsProtocol {
    let replies: Int
    let reactions: Int
    let shares: Int
    let quotes: Int
}

struct StubPostActor: ActorProtocol {
    let id = "actor"
    let name: String? = "Actor"
    let handle = "@actor@example.com"
    let avatarUrl = ""
}

struct StubPostMedium: MediaProtocol {
    let url: String
    let thumbnailUrl: String?
    let alt: String?
    let width: Int?
    let height: Int?
}

struct StubPostQuote: QuotedPostProtocol {
    let id: String
    let name: String?
    let published: String
    let content: String
    let actor: StubPostActor
    let media: [StubPostMedium]
}

final class StubEngagementPost: PostProtocol, ReactionCapablePostProtocol {
    let id: String
    let name: String? = nil
    let published = "2026-07-12T00:00:00Z"
    let content = "content"
    let actor = StubPostActor()
    let media: [StubPostMedium] = []
    let summary: String? = nil
    let excerpt = "content"
    let url: String? = nil
    let iri: String
    let sharedPost: StubEngagementPost?
    let quotedPost: StubPostQuote? = nil
    let engagementStats: StubPostEngagementStats
    let viewerHasShared: Bool
    let viewerHasBookmarked: Bool
    let mentionedHandles: [String] = []
    let isArticle = false
    let reactionGroupsSnapshot: [ReactionGroupSnapshot]

    init(
        id: String,
        sharedPost: StubEngagementPost? = nil,
        engagementStats: StubPostEngagementStats,
        viewerHasShared: Bool = false,
        viewerHasBookmarked: Bool = false,
        reactionGroups: [ReactionGroupSnapshot] = []
    ) {
        self.id = id
        iri = "https://example.com/\(id)"
        self.sharedPost = sharedPost
        self.engagementStats = engagementStats
        self.viewerHasShared = viewerHasShared
        self.viewerHasBookmarked = viewerHasBookmarked
        reactionGroupsSnapshot = reactionGroups
    }
}
