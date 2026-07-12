import Foundation

// MARK: - Mention Utilities

func normalizedMentionHandle(_ handle: String) -> String {
    let trimmed = handle.trimmingCharacters(in: .whitespacesAndNewlines)
    let withoutPrefix = trimmed.hasPrefix("@") ? String(trimmed.dropFirst()) : trimmed
    return withoutPrefix.lowercased()
}

func orderedMentionHandles(
    authorHandle: String,
    mentionedHandles: [String],
    excludingHandle: String? = nil
) -> [String] {
    let excludedHandle = excludingHandle.map(normalizedMentionHandle)
    var seen = Set<String>()

    return ([authorHandle] + mentionedHandles).compactMap { handle in
        let normalized = normalizedMentionHandle(handle)
        guard !normalized.isEmpty,
              normalized != excludedHandle,
              seen.insert(normalized).inserted
        else {
            return nil
        }
        return handle
    }
}

/// Extract the post author followed by its selected mention handles.
/// - Parameters:
///   - post: The post to extract mentions from
///   - excludingHandle: The handle to exclude from the mention list (usually the current user's handle)
/// - Returns: Ordered, deduplicated mention handles with the post author first.
func getMentionHandles<P: PostProtocol>(
    from post: P,
    excludingHandle: String? = nil
) -> [String] {
    orderedMentionHandles(
        authorHandle: post.actor.handle,
        mentionedHandles: post.mentionedHandles,
        excludingHandle: excludingHandle
    )
}

// MARK: - EngagementStats Protocol Conformance

extension HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge.Node.EngagementStats: EngagementStatsProtocol {}
extension HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge.Node.SharedPost.EngagementStats: EngagementStatsProtocol {}
extension HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge.Node.EngagementStats: EngagementStatsProtocol {}
extension HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge.Node.SharedPost.EngagementStats: EngagementStatsProtocol {}
extension HackersPub.PersonalTimelineQuery.Data.PersonalTimeline.Edge.Node.EngagementStats: EngagementStatsProtocol {}
extension HackersPub.PersonalTimelineQuery.Data.PersonalTimeline.Edge.Node.SharedPost.EngagementStats: EngagementStatsProtocol {}
extension HackersPub.SearchPostQuery.Data.SearchPost.Edge.Node.EngagementStats: EngagementStatsProtocol {}
extension HackersPub.SearchPostQuery.Data.SearchPost.Edge.Node.SharedPost.EngagementStats: EngagementStatsProtocol {}
extension HackersPub.ActorByHandleQuery.Data.ActorByHandle.Posts.Edge.Node.EngagementStats: EngagementStatsProtocol {}
extension HackersPub.ActorByHandleQuery.Data.ActorByHandle.Posts.Edge.Node.SharedPost.EngagementStats: EngagementStatsProtocol {}
extension HackersPub.ProfilePostFields.EngagementStats: EngagementStatsProtocol {}
extension HackersPub.ProfilePostFields.SharedPost.EngagementStats: EngagementStatsProtocol {}
extension HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsMentionNotification.Post.EngagementStats: EngagementStatsProtocol {}
extension HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsReplyNotification.Post.EngagementStats: EngagementStatsProtocol {}
extension HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsQuoteNotification.Post.EngagementStats: EngagementStatsProtocol {}
extension HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsReactNotification.Post.EngagementStats: EngagementStatsProtocol {}
extension HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsShareNotification.Post.EngagementStats: EngagementStatsProtocol {}
extension HackersPub.PostDetailQuery.Data.Node.AsPost.EngagementStats: EngagementStatsProtocol {}
extension HackersPub.PostDetailQuery.Data.Node.AsPost.SharedPost.EngagementStats: EngagementStatsProtocol {}
extension HackersPub.PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.EngagementStats: EngagementStatsProtocol {}
extension HackersPub.PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.SharedPost.EngagementStats: EngagementStatsProtocol {}
extension HackersPub.PostQuotesQuery.Data.Node.AsPost.Quotes.Edge.Node.EngagementStats: EngagementStatsProtocol {}
extension HackersPub.PostQuotesQuery.Data.Node.AsPost.Quotes.Edge.Node.SharedPost.EngagementStats: EngagementStatsProtocol {}

// MARK: - SearchPost Extensions

extension HackersPub.SearchPostQuery.Data.SearchPost.Edge.Node: PostProtocol {
    typealias SharedPostType = HackersPub.SearchPostQuery.Data.SearchPost.Edge.Node.SharedPost
    typealias QuotedPostType = HackersPub.SearchPostQuery.Data.SearchPost.Edge.Node.QuotedPost
    typealias EngagementStatsType = HackersPub.SearchPostQuery.Data.SearchPost.Edge.Node.EngagementStats

    var isArticle: Bool {
        return __typename == "Article"
    }

    var mentionedHandles: [String] {
        return mentions.edges.map { $0.node.handle }
    }
}

extension HackersPub.SearchPostQuery.Data.SearchPost.Edge.Node.Actor: ActorProtocol {}

extension HackersPub.SearchPostQuery.Data.SearchPost.Edge.Node.Medium: MediaProtocol {}

extension HackersPub.SearchPostQuery.Data.SearchPost.Edge.Node.SharedPost: PostProtocol {
    typealias SharedPostType = HackersPub.SearchPostQuery.Data.SearchPost.Edge.Node.SharedPost
    typealias QuotedPostType = HackersPub.SearchPostQuery.Data.SearchPost.Edge.Node.SharedPost.QuotedPost
    typealias EngagementStatsType = HackersPub.SearchPostQuery.Data.SearchPost.Edge.Node.SharedPost.EngagementStats
    var sharedPost: HackersPub.SearchPostQuery.Data.SearchPost.Edge.Node.SharedPost? {
        nil
    }

    var isArticle: Bool {
        return __typename == "Article"
    }

    var mentionedHandles: [String] {
        return mentions.edges.map { $0.node.handle }
    }
}

extension HackersPub.SearchPostQuery.Data.SearchPost.Edge.Node.SharedPost.Actor: ActorProtocol {}

extension HackersPub.SearchPostQuery.Data.SearchPost.Edge.Node.SharedPost.Medium: MediaProtocol {}

extension HackersPub.SearchPostQuery.Data.SearchPost.Edge.Node.SharedPost.QuotedPost: QuotedPostProtocol {}

extension HackersPub.SearchPostQuery.Data.SearchPost.Edge.Node.SharedPost.QuotedPost.Actor: ActorProtocol {}

extension HackersPub.SearchPostQuery.Data.SearchPost.Edge.Node.SharedPost.QuotedPost.Medium: MediaProtocol {}

extension HackersPub.SearchPostQuery.Data.SearchPost.Edge.Node.QuotedPost: QuotedPostProtocol {}

extension HackersPub.SearchPostQuery.Data.SearchPost.Edge.Node.QuotedPost.Actor: ActorProtocol {}

extension HackersPub.SearchPostQuery.Data.SearchPost.Edge.Node.QuotedPost.Medium: MediaProtocol {}

// MARK: - ActorByHandle Extensions

extension HackersPub.ActorByHandleQuery.Data.ActorByHandle.Posts.Edge.Node: PostProtocol {
    typealias SharedPostType = HackersPub.ActorByHandleQuery.Data.ActorByHandle.Posts.Edge.Node.SharedPost
    typealias QuotedPostType = HackersPub.ActorByHandleQuery.Data.ActorByHandle.Posts.Edge.Node.QuotedPost
    typealias EngagementStatsType = HackersPub.ActorByHandleQuery.Data.ActorByHandle.Posts.Edge.Node.EngagementStats

    var isArticle: Bool {
        return __typename == "Article"
    }

    var mentionedHandles: [String] {
        return mentions.edges.map { $0.node.handle }
    }
}

extension HackersPub.ActorByHandleQuery.Data.ActorByHandle.Posts.Edge.Node.Actor: ActorProtocol {}

extension HackersPub.ActorByHandleQuery.Data.ActorByHandle.Posts.Edge.Node.Medium: MediaProtocol {}

extension HackersPub.ActorByHandleQuery.Data.ActorByHandle.Posts.Edge.Node.SharedPost: PostProtocol {
    typealias SharedPostType = HackersPub.ActorByHandleQuery.Data.ActorByHandle.Posts.Edge.Node.SharedPost
    typealias QuotedPostType = HackersPub.ActorByHandleQuery.Data.ActorByHandle.Posts.Edge.Node.SharedPost.QuotedPost
    typealias EngagementStatsType = HackersPub.ActorByHandleQuery.Data.ActorByHandle.Posts.Edge.Node.SharedPost.EngagementStats
    var sharedPost: HackersPub.ActorByHandleQuery.Data.ActorByHandle.Posts.Edge.Node.SharedPost? {
        nil
    }

    var isArticle: Bool {
        return __typename == "Article"
    }

    var mentionedHandles: [String] {
        return mentions.edges.map { $0.node.handle }
    }
}

extension HackersPub.ActorByHandleQuery.Data.ActorByHandle.Posts.Edge.Node.SharedPost.Actor: ActorProtocol {}

extension HackersPub.ActorByHandleQuery.Data.ActorByHandle.Posts.Edge.Node.SharedPost.Medium: MediaProtocol {}

extension HackersPub.ActorByHandleQuery.Data.ActorByHandle.Posts.Edge.Node.SharedPost.QuotedPost: QuotedPostProtocol {}

extension HackersPub.ActorByHandleQuery.Data.ActorByHandle.Posts.Edge.Node.SharedPost.QuotedPost.Actor: ActorProtocol {}

extension HackersPub.ActorByHandleQuery.Data.ActorByHandle.Posts.Edge.Node.SharedPost.QuotedPost.Medium: MediaProtocol {}

extension HackersPub.ActorByHandleQuery.Data.ActorByHandle.Posts.Edge.Node.QuotedPost: QuotedPostProtocol {}

extension HackersPub.ActorByHandleQuery.Data.ActorByHandle.Posts.Edge.Node.QuotedPost.Actor: ActorProtocol {}

extension HackersPub.ActorByHandleQuery.Data.ActorByHandle.Posts.Edge.Node.QuotedPost.Medium: MediaProtocol {}

extension HackersPub.ActorByHandleQuery.Data.ActorByHandle: Identifiable {}

// MARK: - Profile Tab Post Extensions

extension HackersPub.ProfilePostFields.Actor: ActorProtocol {}

extension HackersPub.ProfilePostFields.Medium: MediaProtocol {}

extension HackersPub.ProfilePostFields.SharedPost: PostProtocol {
    typealias SharedPostType = HackersPub.ProfilePostFields.SharedPost
    typealias QuotedPostType = HackersPub.ProfilePostFields.SharedPost.QuotedPost
    typealias EngagementStatsType = HackersPub.ProfilePostFields.SharedPost.EngagementStats
    var sharedPost: HackersPub.ProfilePostFields.SharedPost? {
        nil
    }

    var isArticle: Bool {
        return __typename == "Article"
    }

    var mentionedHandles: [String] {
        return mentions.edges.map { $0.node.handle }
    }
}

extension HackersPub.ProfilePostFields.SharedPost.Actor: ActorProtocol {}

extension HackersPub.ProfilePostFields.SharedPost.Medium: MediaProtocol {}

extension HackersPub.ProfilePostFields.SharedPost.QuotedPost: QuotedPostProtocol {}

extension HackersPub.ProfilePostFields.SharedPost.QuotedPost.Actor: ActorProtocol {}

extension HackersPub.ProfilePostFields.SharedPost.QuotedPost.Medium: MediaProtocol {}

extension HackersPub.ProfilePostFields.QuotedPost: QuotedPostProtocol {}

extension HackersPub.ProfilePostFields.QuotedPost.Actor: ActorProtocol {}

extension HackersPub.ProfilePostFields.QuotedPost.Medium: MediaProtocol {}

extension HackersPub.ActorNotesQuery.Data.ActorByHandle.Notes.Edge.Node: PostProtocol {
    typealias SharedPostType = HackersPub.ProfilePostFields.SharedPost
    typealias QuotedPostType = HackersPub.ProfilePostFields.QuotedPost
    typealias EngagementStatsType = HackersPub.ProfilePostFields.EngagementStats

    var isArticle: Bool {
        return __typename == "Article"
    }

    var mentionedHandles: [String] {
        return mentions.edges.map { $0.node.handle }
    }
}

extension HackersPub.ActorArticlesQuery.Data.ActorByHandle.Articles.Edge.Node: PostProtocol {
    typealias SharedPostType = HackersPub.ProfilePostFields.SharedPost
    typealias QuotedPostType = HackersPub.ProfilePostFields.QuotedPost
    typealias EngagementStatsType = HackersPub.ProfilePostFields.EngagementStats

    var isArticle: Bool {
        return __typename == "Article"
    }

    var mentionedHandles: [String] {
        return mentions.edges.map { $0.node.handle }
    }
}

// MARK: - Bookmarks Extensions

extension HackersPub.BookmarksQuery.Data.Bookmarks.Edge.Node: PostProtocol {
    typealias SharedPostType = HackersPub.ProfilePostFields.SharedPost
    typealias QuotedPostType = HackersPub.ProfilePostFields.QuotedPost
    typealias EngagementStatsType = HackersPub.ProfilePostFields.EngagementStats

    var isArticle: Bool {
        return __typename == "Article"
    }

    var mentionedHandles: [String] {
        return mentions.edges.map { $0.node.handle }
    }
}

// MARK: - News Extensions

extension HackersPub.NewsStoryDetailQuery.Data.NewsStory.SharingPosts.Edge.Node: PostProtocol {
    typealias SharedPostType = HackersPub.ProfilePostFields.SharedPost
    typealias QuotedPostType = HackersPub.ProfilePostFields.QuotedPost
    typealias EngagementStatsType = HackersPub.ProfilePostFields.EngagementStats

    var isArticle: Bool {
        return __typename == "Article"
    }

    var mentionedHandles: [String] {
        return mentions.edges.map { $0.node.handle }
    }
}

// MARK: - Notification Preview Extensions

private typealias NotificationPost = HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node
private typealias MentionNotificationPost = NotificationPost.AsMentionNotification.Post
private typealias ReplyNotificationPost = NotificationPost.AsReplyNotification.Post
private typealias QuoteNotificationPost = NotificationPost.AsQuoteNotification.Post
private typealias ReactNotificationPost = NotificationPost.AsReactNotification.Post
private typealias ShareNotificationPost = NotificationPost.AsShareNotification.Post

extension MentionNotificationPost: NotificationPostPreviewSource {
    var notificationPostPreviewFields: NotificationPostPreviewFields {
        NotificationPostPreviewFields(
            postID: id,
            author: PostPreviewAuthor(name: actor.name, handle: actor.handle, avatarURL: actor.avatarUrl),
            title: name,
            published: published,
            content: content,
            summary: summary,
            media: media.map {
                PostPreviewMedia(url: $0.url, thumbnailURL: $0.thumbnailUrl, alt: $0.alt)
            }
        )
    }
}

extension ReplyNotificationPost: NotificationPostPreviewSource {
    var notificationPostPreviewFields: NotificationPostPreviewFields {
        NotificationPostPreviewFields(
            postID: id,
            author: PostPreviewAuthor(name: actor.name, handle: actor.handle, avatarURL: actor.avatarUrl),
            title: name,
            published: published,
            content: content,
            summary: summary,
            media: media.map {
                PostPreviewMedia(url: $0.url, thumbnailURL: $0.thumbnailUrl, alt: $0.alt)
            }
        )
    }
}

extension QuoteNotificationPost: NotificationPostPreviewSource {
    var notificationPostPreviewFields: NotificationPostPreviewFields {
        NotificationPostPreviewFields(
            postID: id,
            author: PostPreviewAuthor(name: actor.name, handle: actor.handle, avatarURL: actor.avatarUrl),
            title: name,
            published: published,
            content: content,
            summary: summary,
            media: media.map {
                PostPreviewMedia(url: $0.url, thumbnailURL: $0.thumbnailUrl, alt: $0.alt)
            }
        )
    }
}

extension ReactNotificationPost: NotificationPostPreviewSource {
    var notificationPostPreviewFields: NotificationPostPreviewFields {
        NotificationPostPreviewFields(
            postID: id,
            author: PostPreviewAuthor(name: actor.name, handle: actor.handle, avatarURL: actor.avatarUrl),
            title: name,
            published: published,
            content: content,
            summary: summary,
            media: media.map {
                PostPreviewMedia(url: $0.url, thumbnailURL: $0.thumbnailUrl, alt: $0.alt)
            }
        )
    }
}

extension ShareNotificationPost: NotificationPostPreviewSource {
    var notificationPostPreviewFields: NotificationPostPreviewFields {
        NotificationPostPreviewFields(
            postID: id,
            author: PostPreviewAuthor(name: actor.name, handle: actor.handle, avatarURL: actor.avatarUrl),
            title: name,
            published: published,
            content: content,
            summary: summary,
            media: media.map {
                PostPreviewMedia(url: $0.url, thumbnailURL: $0.thumbnailUrl, alt: $0.alt)
            }
        )
    }
}

// MARK: - PostDetail Extensions

extension HackersPub.PostDetailQuery.Data.Node.AsPost: PostProtocol {
    typealias SharedPostType = HackersPub.PostDetailQuery.Data.Node.AsPost.SharedPost
    typealias QuotedPostType = HackersPub.PostDetailQuery.Data.Node.AsPost.QuotedPost
    typealias EngagementStatsType = HackersPub.PostDetailQuery.Data.Node.AsPost.EngagementStats

    var isArticle: Bool {
        return __typename == "Article"
    }

    var mentionedHandles: [String] {
        return mentions.edges.map { $0.node.handle }
    }
}

extension HackersPub.PostDetailQuery.Data.Node.AsPost.Actor: ActorProtocol {}

extension HackersPub.PostDetailQuery.Data.Node.AsPost.Medium: MediaProtocol {}

extension HackersPub.PostDetailQuery.Data.Node.AsPost.SharedPost: PostProtocol {
    typealias SharedPostType = HackersPub.PostDetailQuery.Data.Node.AsPost.SharedPost
    typealias QuotedPostType = HackersPub.PostDetailQuery.Data.Node.AsPost.SharedPost.QuotedPost
    typealias EngagementStatsType = HackersPub.PostDetailQuery.Data.Node.AsPost.SharedPost.EngagementStats
    var sharedPost: SharedPostType? {
        nil
    }

    var isArticle: Bool {
        return __typename == "Article"
    }

    var mentionedHandles: [String] {
        return mentions.edges.map { $0.node.handle }
    }
}

extension HackersPub.PostDetailQuery.Data.Node.AsPost.SharedPost.Actor: ActorProtocol {}

extension HackersPub.PostDetailQuery.Data.Node.AsPost.SharedPost.Medium: MediaProtocol {}

extension HackersPub.PostDetailQuery.Data.Node.AsPost.SharedPost.QuotedPost: QuotedPostProtocol {}

extension HackersPub.PostDetailQuery.Data.Node.AsPost.SharedPost.QuotedPost.Actor: ActorProtocol {}

extension HackersPub.PostDetailQuery.Data.Node.AsPost.SharedPost.QuotedPost.Medium: MediaProtocol {}

extension HackersPub.PostDetailQuery.Data.Node.AsPost.QuotedPost: QuotedPostProtocol {}

extension HackersPub.PostDetailQuery.Data.Node.AsPost.QuotedPost.Actor: ActorProtocol {}

extension HackersPub.PostDetailQuery.Data.Node.AsPost.QuotedPost.Medium: MediaProtocol {}

// PostDetail Replies Extensions

extension HackersPub.PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node: PostProtocol {
    typealias SharedPostType = HackersPub.PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.SharedPost
    typealias QuotedPostType = HackersPub.PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.QuotedPost
    typealias EngagementStatsType = HackersPub.PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.EngagementStats

    var isArticle: Bool {
        return __typename == "Article"
    }

    var mentionedHandles: [String] {
        return mentions.edges.map { $0.node.handle }
    }
}

extension HackersPub.PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.Actor: ActorProtocol {}

extension HackersPub.PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.Medium: MediaProtocol {}

extension HackersPub.PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.SharedPost: PostProtocol {
    typealias SharedPostType = HackersPub.PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.SharedPost
    typealias QuotedPostType = HackersPub.PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.SharedPost.QuotedPost
    typealias EngagementStatsType = HackersPub.PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.SharedPost.EngagementStats
    var sharedPost: SharedPostType? {
        nil
    }

    var isArticle: Bool {
        return __typename == "Article"
    }

    var mentionedHandles: [String] {
        return mentions.edges.map { $0.node.handle }
    }
}

extension HackersPub.PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.SharedPost.Actor: ActorProtocol {}

extension HackersPub.PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.SharedPost.Medium: MediaProtocol {}

extension HackersPub.PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.SharedPost.QuotedPost: QuotedPostProtocol {}

extension HackersPub.PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.SharedPost.QuotedPost.Actor: ActorProtocol {}

extension HackersPub.PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.SharedPost.QuotedPost.Medium: MediaProtocol {}

extension HackersPub.PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.QuotedPost: QuotedPostProtocol {}

extension HackersPub.PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.QuotedPost.Actor: ActorProtocol {}

extension HackersPub.PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.QuotedPost.Medium: MediaProtocol {}

// MARK: - PostQuotes Extensions

extension HackersPub.PostQuotesQuery.Data.Node.AsPost.Quotes.Edge.Node: PostProtocol {
    typealias SharedPostType = HackersPub.PostQuotesQuery.Data.Node.AsPost.Quotes.Edge.Node.SharedPost
    typealias QuotedPostType = HackersPub.PostQuotesQuery.Data.Node.AsPost.Quotes.Edge.Node.QuotedPost
    typealias EngagementStatsType = HackersPub.PostQuotesQuery.Data.Node.AsPost.Quotes.Edge.Node.EngagementStats

    var isArticle: Bool {
        return __typename == "Article"
    }

    var mentionedHandles: [String] {
        return mentions.edges.map { $0.node.handle }
    }
}

extension HackersPub.PostQuotesQuery.Data.Node.AsPost.Quotes.Edge.Node.Actor: ActorProtocol {}

extension HackersPub.PostQuotesQuery.Data.Node.AsPost.Quotes.Edge.Node.Medium: MediaProtocol {}

extension HackersPub.PostQuotesQuery.Data.Node.AsPost.Quotes.Edge.Node.SharedPost: PostProtocol {
    typealias SharedPostType = HackersPub.PostQuotesQuery.Data.Node.AsPost.Quotes.Edge.Node.SharedPost
    typealias QuotedPostType = HackersPub.PostQuotesQuery.Data.Node.AsPost.Quotes.Edge.Node.SharedPost.QuotedPost
    typealias EngagementStatsType = HackersPub.PostQuotesQuery.Data.Node.AsPost.Quotes.Edge.Node.SharedPost.EngagementStats
    var sharedPost: SharedPostType? {
        nil
    }

    var isArticle: Bool {
        return __typename == "Article"
    }

    var mentionedHandles: [String] {
        return mentions.edges.map { $0.node.handle }
    }
}

extension HackersPub.PostQuotesQuery.Data.Node.AsPost.Quotes.Edge.Node.SharedPost.Actor: ActorProtocol {}

extension HackersPub.PostQuotesQuery.Data.Node.AsPost.Quotes.Edge.Node.SharedPost.Medium: MediaProtocol {}

extension HackersPub.PostQuotesQuery.Data.Node.AsPost.Quotes.Edge.Node.SharedPost.QuotedPost: QuotedPostProtocol {}

extension HackersPub.PostQuotesQuery.Data.Node.AsPost.Quotes.Edge.Node.SharedPost.QuotedPost.Actor: ActorProtocol {}

extension HackersPub.PostQuotesQuery.Data.Node.AsPost.Quotes.Edge.Node.SharedPost.QuotedPost.Medium: MediaProtocol {}

extension HackersPub.PostQuotesQuery.Data.Node.AsPost.Quotes.Edge.Node.QuotedPost: QuotedPostProtocol {}

extension HackersPub.PostQuotesQuery.Data.Node.AsPost.Quotes.Edge.Node.QuotedPost.Actor: ActorProtocol {}

extension HackersPub.PostQuotesQuery.Data.Node.AsPost.Quotes.Edge.Node.QuotedPost.Medium: MediaProtocol {}

// MARK: - ReactionCapablePostProtocol

private struct EmojiReactionSnapshotInput {
    let emoji: String
    let totalCount: Int
    let viewerHasReacted: Bool
}

private struct CustomEmojiReactionSnapshotInput {
    let id: String
    let name: String
    let imageURL: String
    let totalCount: Int
    let viewerHasReacted: Bool
}

private func reactionGroupSnapshots<Group>(
    _ groups: [Group],
    emoji: (Group) -> EmojiReactionSnapshotInput?,
    customEmoji: (Group) -> CustomEmojiReactionSnapshotInput?
) -> [ReactionGroupSnapshot] {
    groups.compactMap { group in
        if let emoji = emoji(group) {
            return ReactionGroupSnapshot(
                id: "emoji:\(emoji.emoji)",
                emoji: emoji.emoji,
                customEmojiName: nil,
                customEmojiImageUrl: nil,
                totalCount: emoji.totalCount,
                viewerHasReacted: emoji.viewerHasReacted
            )
        }
        if let customEmoji = customEmoji(group) {
            return ReactionGroupSnapshot(
                id: "custom:\(customEmoji.id)",
                emoji: nil,
                customEmojiName: customEmoji.name,
                customEmojiImageUrl: customEmoji.imageURL,
                totalCount: customEmoji.totalCount,
                viewerHasReacted: customEmoji.viewerHasReacted
            )
        }
        return nil
    }
}

extension HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge.Node: ReactionCapablePostProtocol {
    var reactionGroupsSnapshot: [ReactionGroupSnapshot] {
        reactionGroupSnapshots(
            reactionGroups,
            emoji: emojiReactionSnapshot,
            customEmoji: customEmojiReactionSnapshot
        )
    }

    private func emojiReactionSnapshot(
        _ group: HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge.Node.ReactionGroup
    ) -> EmojiReactionSnapshotInput? {
        guard let group = group.asEmojiReactionGroup else { return nil }
        return EmojiReactionSnapshotInput(
            emoji: group.emoji,
            totalCount: group.reactors.totalCount,
            viewerHasReacted: group.reactors.viewerHasReacted
        )
    }

    private func customEmojiReactionSnapshot(
        _ group: HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge.Node.ReactionGroup
    ) -> CustomEmojiReactionSnapshotInput? {
        guard let group = group.asCustomEmojiReactionGroup else { return nil }
        return CustomEmojiReactionSnapshotInput(
            id: group.customEmoji.id,
            name: group.customEmoji.name,
            imageURL: group.customEmoji.imageUrl,
            totalCount: group.reactors.totalCount,
            viewerHasReacted: group.reactors.viewerHasReacted
        )
    }
}

extension HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge.Node: ReactionCapablePostProtocol {
    var reactionGroupsSnapshot: [ReactionGroupSnapshot] {
        reactionGroupSnapshots(reactionGroups, emoji: emojiReactionSnapshot, customEmoji: customEmojiReactionSnapshot)
    }

    private func emojiReactionSnapshot(_ group: ReactionGroup) -> EmojiReactionSnapshotInput? {
        guard let group = group.asEmojiReactionGroup else { return nil }
        return EmojiReactionSnapshotInput(
            emoji: group.emoji,
            totalCount: group.reactors.totalCount,
            viewerHasReacted: group.reactors.viewerHasReacted
        )
    }

    private func customEmojiReactionSnapshot(_ group: ReactionGroup) -> CustomEmojiReactionSnapshotInput? {
        guard let group = group.asCustomEmojiReactionGroup else { return nil }
        return CustomEmojiReactionSnapshotInput(
            id: group.customEmoji.id,
            name: group.customEmoji.name,
            imageURL: group.customEmoji.imageUrl,
            totalCount: group.reactors.totalCount,
            viewerHasReacted: group.reactors.viewerHasReacted
        )
    }
}

extension HackersPub.PersonalTimelineQuery.Data.PersonalTimeline.Edge.Node: ReactionCapablePostProtocol {
    var reactionGroupsSnapshot: [ReactionGroupSnapshot] {
        reactionGroupSnapshots(reactionGroups, emoji: emojiReactionSnapshot, customEmoji: customEmojiReactionSnapshot)
    }

    private func emojiReactionSnapshot(_ group: ReactionGroup) -> EmojiReactionSnapshotInput? {
        guard let group = group.asEmojiReactionGroup else { return nil }
        return EmojiReactionSnapshotInput(
            emoji: group.emoji,
            totalCount: group.reactors.totalCount,
            viewerHasReacted: group.reactors.viewerHasReacted
        )
    }

    private func customEmojiReactionSnapshot(_ group: ReactionGroup) -> CustomEmojiReactionSnapshotInput? {
        guard let group = group.asCustomEmojiReactionGroup else { return nil }
        return CustomEmojiReactionSnapshotInput(
            id: group.customEmoji.id,
            name: group.customEmoji.name,
            imageURL: group.customEmoji.imageUrl,
            totalCount: group.reactors.totalCount,
            viewerHasReacted: group.reactors.viewerHasReacted
        )
    }
}

extension HackersPub.SearchPostQuery.Data.SearchPost.Edge.Node: ReactionCapablePostProtocol {
    var reactionGroupsSnapshot: [ReactionGroupSnapshot] {
        reactionGroupSnapshots(reactionGroups, emoji: emojiReactionSnapshot, customEmoji: customEmojiReactionSnapshot)
    }

    private func emojiReactionSnapshot(_ group: ReactionGroup) -> EmojiReactionSnapshotInput? {
        guard let group = group.asEmojiReactionGroup else { return nil }
        return EmojiReactionSnapshotInput(
            emoji: group.emoji,
            totalCount: group.reactors.totalCount,
            viewerHasReacted: group.reactors.viewerHasReacted
        )
    }

    private func customEmojiReactionSnapshot(_ group: ReactionGroup) -> CustomEmojiReactionSnapshotInput? {
        guard let group = group.asCustomEmojiReactionGroup else { return nil }
        return CustomEmojiReactionSnapshotInput(
            id: group.customEmoji.id,
            name: group.customEmoji.name,
            imageURL: group.customEmoji.imageUrl,
            totalCount: group.reactors.totalCount,
            viewerHasReacted: group.reactors.viewerHasReacted
        )
    }
}

extension HackersPub.ActorByHandleQuery.Data.ActorByHandle.Posts.Edge.Node: ReactionCapablePostProtocol {
    var reactionGroupsSnapshot: [ReactionGroupSnapshot] {
        reactionGroupSnapshots(reactionGroups, emoji: emojiReactionSnapshot, customEmoji: customEmojiReactionSnapshot)
    }

    private func emojiReactionSnapshot(_ group: ReactionGroup) -> EmojiReactionSnapshotInput? {
        guard let group = group.asEmojiReactionGroup else { return nil }
        return EmojiReactionSnapshotInput(
            emoji: group.emoji,
            totalCount: group.reactors.totalCount,
            viewerHasReacted: group.reactors.viewerHasReacted
        )
    }

    private func customEmojiReactionSnapshot(_ group: ReactionGroup) -> CustomEmojiReactionSnapshotInput? {
        guard let group = group.asCustomEmojiReactionGroup else { return nil }
        return CustomEmojiReactionSnapshotInput(
            id: group.customEmoji.id,
            name: group.customEmoji.name,
            imageURL: group.customEmoji.imageUrl,
            totalCount: group.reactors.totalCount,
            viewerHasReacted: group.reactors.viewerHasReacted
        )
    }
}

extension HackersPub.ActorNotesQuery.Data.ActorByHandle.Notes.Edge.Node: ReactionCapablePostProtocol {
    var reactionGroupsSnapshot: [ReactionGroupSnapshot] {
        reactionGroupSnapshots(reactionGroups, emoji: emojiReactionSnapshot, customEmoji: customEmojiReactionSnapshot)
    }

    private func emojiReactionSnapshot(_ group: ReactionGroup) -> EmojiReactionSnapshotInput? {
        guard let group = group.asEmojiReactionGroup else { return nil }
        return EmojiReactionSnapshotInput(
            emoji: group.emoji,
            totalCount: group.reactors.totalCount,
            viewerHasReacted: group.reactors.viewerHasReacted
        )
    }

    private func customEmojiReactionSnapshot(_ group: ReactionGroup) -> CustomEmojiReactionSnapshotInput? {
        guard let group = group.asCustomEmojiReactionGroup else { return nil }
        return CustomEmojiReactionSnapshotInput(
            id: group.customEmoji.id,
            name: group.customEmoji.name,
            imageURL: group.customEmoji.imageUrl,
            totalCount: group.reactors.totalCount,
            viewerHasReacted: group.reactors.viewerHasReacted
        )
    }
}

extension HackersPub.ActorArticlesQuery.Data.ActorByHandle.Articles.Edge.Node: ReactionCapablePostProtocol {
    var reactionGroupsSnapshot: [ReactionGroupSnapshot] {
        reactionGroupSnapshots(reactionGroups, emoji: emojiReactionSnapshot, customEmoji: customEmojiReactionSnapshot)
    }

    private func emojiReactionSnapshot(_ group: ReactionGroup) -> EmojiReactionSnapshotInput? {
        guard let group = group.asEmojiReactionGroup else { return nil }
        return EmojiReactionSnapshotInput(
            emoji: group.emoji,
            totalCount: group.reactors.totalCount,
            viewerHasReacted: group.reactors.viewerHasReacted
        )
    }

    private func customEmojiReactionSnapshot(_ group: ReactionGroup) -> CustomEmojiReactionSnapshotInput? {
        guard let group = group.asCustomEmojiReactionGroup else { return nil }
        return CustomEmojiReactionSnapshotInput(
            id: group.customEmoji.id,
            name: group.customEmoji.name,
            imageURL: group.customEmoji.imageUrl,
            totalCount: group.reactors.totalCount,
            viewerHasReacted: group.reactors.viewerHasReacted
        )
    }
}

extension HackersPub.BookmarksQuery.Data.Bookmarks.Edge.Node: ReactionCapablePostProtocol {
    var reactionGroupsSnapshot: [ReactionGroupSnapshot] {
        reactionGroupSnapshots(reactionGroups, emoji: emojiReactionSnapshot, customEmoji: customEmojiReactionSnapshot)
    }

    private func emojiReactionSnapshot(_ group: ReactionGroup) -> EmojiReactionSnapshotInput? {
        guard let group = group.asEmojiReactionGroup else { return nil }
        return EmojiReactionSnapshotInput(
            emoji: group.emoji,
            totalCount: group.reactors.totalCount,
            viewerHasReacted: group.reactors.viewerHasReacted
        )
    }

    private func customEmojiReactionSnapshot(_ group: ReactionGroup) -> CustomEmojiReactionSnapshotInput? {
        guard let group = group.asCustomEmojiReactionGroup else { return nil }
        return CustomEmojiReactionSnapshotInput(
            id: group.customEmoji.id,
            name: group.customEmoji.name,
            imageURL: group.customEmoji.imageUrl,
            totalCount: group.reactors.totalCount,
            viewerHasReacted: group.reactors.viewerHasReacted
        )
    }
}

extension HackersPub.NewsStoryDetailQuery.Data.NewsStory.SharingPosts.Edge.Node: ReactionCapablePostProtocol {
    var reactionGroupsSnapshot: [ReactionGroupSnapshot] {
        reactionGroupSnapshots(reactionGroups, emoji: emojiReactionSnapshot, customEmoji: customEmojiReactionSnapshot)
    }

    private func emojiReactionSnapshot(_ group: ReactionGroup) -> EmojiReactionSnapshotInput? {
        guard let group = group.asEmojiReactionGroup else { return nil }
        return EmojiReactionSnapshotInput(
            emoji: group.emoji,
            totalCount: group.reactors.totalCount,
            viewerHasReacted: group.reactors.viewerHasReacted
        )
    }

    private func customEmojiReactionSnapshot(_ group: ReactionGroup) -> CustomEmojiReactionSnapshotInput? {
        guard let group = group.asCustomEmojiReactionGroup else { return nil }
        return CustomEmojiReactionSnapshotInput(
            id: group.customEmoji.id,
            name: group.customEmoji.name,
            imageURL: group.customEmoji.imageUrl,
            totalCount: group.reactors.totalCount,
            viewerHasReacted: group.reactors.viewerHasReacted
        )
    }
}

extension HackersPub.PostDetailQuery.Data.Node.AsPost: ReactionCapablePostProtocol {
    var reactionGroupsSnapshot: [ReactionGroupSnapshot] {
        reactionGroupSnapshots(reactionGroups, emoji: emojiReactionSnapshot, customEmoji: customEmojiReactionSnapshot)
    }

    private func emojiReactionSnapshot(_ group: ReactionGroup) -> EmojiReactionSnapshotInput? {
        guard let group = group.asEmojiReactionGroup else { return nil }
        return EmojiReactionSnapshotInput(
            emoji: group.emoji,
            totalCount: group.reactors.totalCount,
            viewerHasReacted: group.reactors.viewerHasReacted
        )
    }

    private func customEmojiReactionSnapshot(_ group: ReactionGroup) -> CustomEmojiReactionSnapshotInput? {
        guard let group = group.asCustomEmojiReactionGroup else { return nil }
        return CustomEmojiReactionSnapshotInput(
            id: group.customEmoji.id,
            name: group.customEmoji.name,
            imageURL: group.customEmoji.imageUrl,
            totalCount: group.reactors.totalCount,
            viewerHasReacted: group.reactors.viewerHasReacted
        )
    }
}

extension HackersPub.PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node: ReactionCapablePostProtocol {
    var reactionGroupsSnapshot: [ReactionGroupSnapshot] {
        reactionGroupSnapshots(reactionGroups, emoji: emojiReactionSnapshot, customEmoji: customEmojiReactionSnapshot)
    }

    private func emojiReactionSnapshot(_ group: ReactionGroup) -> EmojiReactionSnapshotInput? {
        guard let group = group.asEmojiReactionGroup else { return nil }
        return EmojiReactionSnapshotInput(
            emoji: group.emoji,
            totalCount: group.reactors.totalCount,
            viewerHasReacted: group.reactors.viewerHasReacted
        )
    }

    private func customEmojiReactionSnapshot(_ group: ReactionGroup) -> CustomEmojiReactionSnapshotInput? {
        guard let group = group.asCustomEmojiReactionGroup else { return nil }
        return CustomEmojiReactionSnapshotInput(
            id: group.customEmoji.id,
            name: group.customEmoji.name,
            imageURL: group.customEmoji.imageUrl,
            totalCount: group.reactors.totalCount,
            viewerHasReacted: group.reactors.viewerHasReacted
        )
    }
}

extension HackersPub.PostQuotesQuery.Data.Node.AsPost.Quotes.Edge.Node: ReactionCapablePostProtocol {
    var reactionGroupsSnapshot: [ReactionGroupSnapshot] {
        reactionGroupSnapshots(reactionGroups, emoji: emojiReactionSnapshot, customEmoji: customEmojiReactionSnapshot)
    }

    private func emojiReactionSnapshot(_ group: ReactionGroup) -> EmojiReactionSnapshotInput? {
        guard let group = group.asEmojiReactionGroup else { return nil }
        return EmojiReactionSnapshotInput(
            emoji: group.emoji,
            totalCount: group.reactors.totalCount,
            viewerHasReacted: group.reactors.viewerHasReacted
        )
    }

    private func customEmojiReactionSnapshot(_ group: ReactionGroup) -> CustomEmojiReactionSnapshotInput? {
        guard let group = group.asCustomEmojiReactionGroup else { return nil }
        return CustomEmojiReactionSnapshotInput(
            id: group.customEmoji.id,
            name: group.customEmoji.name,
            imageURL: group.customEmoji.imageUrl,
            totalCount: group.reactors.totalCount,
            viewerHasReacted: group.reactors.viewerHasReacted
        )
    }
}
