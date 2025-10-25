import Foundation

// MARK: - Mention Utilities

/// Extract mention handles from a generic post (without explicit mention data)
/// - Parameters:
///   - post: The post to extract mentions from
///   - excludingHandle: The handle to exclude from the mention list (usually the current user's handle)
/// - Returns: Array containing only the post author (since other mentions aren't available)
func getMentionHandles<P: PostProtocol>(
    from post: P,
    excludingHandle: String? = nil
) -> [String] {
    var handles: [String] = []
    
    // Add the post author as the first mention
    handles.append(post.actor.handle)
    
    // Add other mentioned users from the mentions field
    for handle in post.mentionedHandles {
        if !handles.contains(handle) {
            handles.append(handle)
        }
    }

    // Remove the specified handle to avoid self-mentions
    if let excludingHandle = excludingHandle {
        handles.removeAll { $0 == excludingHandle }
    }
    
    return handles
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
extension HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsMentionNotification.Post.EngagementStats: EngagementStatsProtocol {}
extension HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsReplyNotification.Post.EngagementStats: EngagementStatsProtocol {}
extension HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsQuoteNotification.Post.EngagementStats: EngagementStatsProtocol {}
extension HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsReactNotification.Post.EngagementStats: EngagementStatsProtocol {}
extension HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsShareNotification.Post.EngagementStats: EngagementStatsProtocol {}
extension HackersPub.PostDetailQuery.Data.Node.AsPost.EngagementStats: EngagementStatsProtocol {}
extension HackersPub.PostDetailQuery.Data.Node.AsPost.SharedPost.EngagementStats: EngagementStatsProtocol {}
extension HackersPub.PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.EngagementStats: EngagementStatsProtocol {}
extension HackersPub.PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.SharedPost.EngagementStats: EngagementStatsProtocol {}

// MARK: - SearchPost Extensions

extension HackersPub.SearchPostQuery.Data.SearchPost.Edge.Node: PostProtocol {
    typealias SharedPostType = HackersPub.SearchPostQuery.Data.SearchPost.Edge.Node.SharedPost
    typealias EngagementStatsType = HackersPub.SearchPostQuery.Data.SearchPost.Edge.Node.EngagementStats

    var isArticle: Bool {
        // Temporarily disabled - just show all posts as regular posts
        return false
    }
    
    var mentionedHandles: [String] {
        return self.mentions.edges.map { $0.node.handle }
    }
}

extension HackersPub.SearchPostQuery.Data.SearchPost.Edge.Node.Actor: ActorProtocol {}

extension HackersPub.SearchPostQuery.Data.SearchPost.Edge.Node.Medium: MediaProtocol {}

extension HackersPub.SearchPostQuery.Data.SearchPost.Edge.Node.SharedPost: PostProtocol {
    typealias SharedPostType = HackersPub.SearchPostQuery.Data.SearchPost.Edge.Node.SharedPost
    typealias EngagementStatsType = HackersPub.SearchPostQuery.Data.SearchPost.Edge.Node.SharedPost.EngagementStats
    var sharedPost: HackersPub.SearchPostQuery.Data.SearchPost.Edge.Node.SharedPost? { nil }

    var isArticle: Bool {
        // Temporarily disabled - just show all posts as regular posts
        return false
    }
    
    var mentionedHandles: [String] {
        return self.mentions.edges.map { $0.node.handle }
    }
}

extension HackersPub.SearchPostQuery.Data.SearchPost.Edge.Node.SharedPost.Actor: ActorProtocol {}

extension HackersPub.SearchPostQuery.Data.SearchPost.Edge.Node.SharedPost.Medium: MediaProtocol {}

// MARK: - ActorByHandle Extensions

extension HackersPub.ActorByHandleQuery.Data.ActorByHandle.Posts.Edge.Node: PostProtocol {
    typealias SharedPostType = HackersPub.ActorByHandleQuery.Data.ActorByHandle.Posts.Edge.Node.SharedPost
    typealias EngagementStatsType = HackersPub.ActorByHandleQuery.Data.ActorByHandle.Posts.Edge.Node.EngagementStats

    var isArticle: Bool {
        // Temporarily disabled - just show all posts as regular posts
        return false
    }
    
    var mentionedHandles: [String] {
        return self.mentions.edges.map { $0.node.handle }
    }
}

extension HackersPub.ActorByHandleQuery.Data.ActorByHandle.Posts.Edge.Node.Actor: ActorProtocol {}

extension HackersPub.ActorByHandleQuery.Data.ActorByHandle.Posts.Edge.Node.Medium: MediaProtocol {}

extension HackersPub.ActorByHandleQuery.Data.ActorByHandle.Posts.Edge.Node.SharedPost: PostProtocol {
    typealias SharedPostType = HackersPub.ActorByHandleQuery.Data.ActorByHandle.Posts.Edge.Node.SharedPost
    typealias EngagementStatsType = HackersPub.ActorByHandleQuery.Data.ActorByHandle.Posts.Edge.Node.SharedPost.EngagementStats
    var sharedPost: HackersPub.ActorByHandleQuery.Data.ActorByHandle.Posts.Edge.Node.SharedPost? { nil }

    var isArticle: Bool {
        // Temporarily disabled - just show all posts as regular posts
        return false
    }
    
    var mentionedHandles: [String] {
        return self.mentions.edges.map { $0.node.handle }
    }
}

extension HackersPub.ActorByHandleQuery.Data.ActorByHandle.Posts.Edge.Node.SharedPost.Actor: ActorProtocol {}

extension HackersPub.ActorByHandleQuery.Data.ActorByHandle.Posts.Edge.Node.SharedPost.Medium: MediaProtocol {}

extension HackersPub.ActorByHandleQuery.Data.ActorByHandle: Identifiable {}

// MARK: - Notifications Extensions

extension HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsMentionNotification.Post: PostProtocol {
    typealias SharedPostType = HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsMentionNotification.Post
    typealias EngagementStatsType = HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsMentionNotification.Post.EngagementStats
    var sharedPost: SharedPostType? { nil }

    var isArticle: Bool {
        return __typename == "Article"
    }
    
    var mentionedHandles: [String] {
        return self.mentions.edges.map { $0.node.handle }
    }
}

extension HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsMentionNotification.Post.Actor: ActorProtocol {}

extension HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsMentionNotification.Post.Medium: MediaProtocol {}

extension HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsReplyNotification.Post: PostProtocol {
    typealias SharedPostType = HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsReplyNotification.Post
    typealias EngagementStatsType = HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsReplyNotification.Post.EngagementStats
    var sharedPost: SharedPostType? { nil }

    var isArticle: Bool {
        return __typename == "Article"
    }
    
    var mentionedHandles: [String] {
        return self.mentions.edges.map { $0.node.handle }
    }
}

extension HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsReplyNotification.Post.Actor: ActorProtocol {}

extension HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsReplyNotification.Post.Medium: MediaProtocol {}

extension HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsQuoteNotification.Post: PostProtocol {
    typealias SharedPostType = HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsQuoteNotification.Post
    typealias EngagementStatsType = HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsQuoteNotification.Post.EngagementStats
    var sharedPost: SharedPostType? { nil }

    var isArticle: Bool {
        return __typename == "Article"
    }
    
    var mentionedHandles: [String] {
        return self.mentions.edges.map { $0.node.handle }
    }
}

extension HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsQuoteNotification.Post.Actor: ActorProtocol {}

extension HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsQuoteNotification.Post.Medium: MediaProtocol {}

extension HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsReactNotification.Post: PostProtocol {
    typealias SharedPostType = HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsReactNotification.Post
    typealias EngagementStatsType = HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsReactNotification.Post.EngagementStats
    var sharedPost: SharedPostType? { nil }

    var isArticle: Bool {
        return __typename == "Article"
    }
    
    var mentionedHandles: [String] {
        return self.mentions.edges.map { $0.node.handle }
    }
}

extension HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsReactNotification.Post.Actor: ActorProtocol {}

extension HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsReactNotification.Post.Medium: MediaProtocol {}

extension HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsShareNotification.Post: PostProtocol {
    typealias SharedPostType = HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsShareNotification.Post
    typealias EngagementStatsType = HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsShareNotification.Post.EngagementStats
    var sharedPost: SharedPostType? { nil }

    var isArticle: Bool {
        return __typename == "Article"
    }
    
    var mentionedHandles: [String] {
        return self.mentions.edges.map { $0.node.handle }
    }
}

extension HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsShareNotification.Post.Actor: ActorProtocol {}

extension HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsShareNotification.Post.Medium: MediaProtocol {}

// MARK: - PostDetail Extensions

extension HackersPub.PostDetailQuery.Data.Node.AsPost: PostProtocol {
    typealias SharedPostType = HackersPub.PostDetailQuery.Data.Node.AsPost.SharedPost
    typealias EngagementStatsType = HackersPub.PostDetailQuery.Data.Node.AsPost.EngagementStats

    var isArticle: Bool {
        return __typename == "Article"
    }
    
    var mentionedHandles: [String] {
        return self.mentions.edges.map { $0.node.handle }
    }
}

extension HackersPub.PostDetailQuery.Data.Node.AsPost.Actor: ActorProtocol {}

extension HackersPub.PostDetailQuery.Data.Node.AsPost.Medium: MediaProtocol {}

extension HackersPub.PostDetailQuery.Data.Node.AsPost.SharedPost: PostProtocol {
    typealias SharedPostType = HackersPub.PostDetailQuery.Data.Node.AsPost.SharedPost
    typealias EngagementStatsType = HackersPub.PostDetailQuery.Data.Node.AsPost.SharedPost.EngagementStats
    var sharedPost: SharedPostType? { nil }

    var isArticle: Bool {
        return __typename == "Article"
    }
    
    var mentionedHandles: [String] {
        return self.mentions.edges.map { $0.node.handle }
    }
}

extension HackersPub.PostDetailQuery.Data.Node.AsPost.SharedPost.Actor: ActorProtocol {}

extension HackersPub.PostDetailQuery.Data.Node.AsPost.SharedPost.Medium: MediaProtocol {}

// PostDetail Replies Extensions

extension HackersPub.PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node: PostProtocol {
    typealias SharedPostType = HackersPub.PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.SharedPost
    typealias EngagementStatsType = HackersPub.PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.EngagementStats

    var isArticle: Bool {
        return __typename == "Article"
    }
    
    var mentionedHandles: [String] {
        return self.mentions.edges.map { $0.node.handle }
    }
}

extension HackersPub.PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.Actor: ActorProtocol {}

extension HackersPub.PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.Medium: MediaProtocol {}

extension HackersPub.PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.SharedPost: PostProtocol {
    typealias SharedPostType = HackersPub.PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.SharedPost
    typealias EngagementStatsType = HackersPub.PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.SharedPost.EngagementStats
    var sharedPost: SharedPostType? { nil }

    var isArticle: Bool {
        return __typename == "Article"
    }
    
    var mentionedHandles: [String] {
        return self.mentions.edges.map { $0.node.handle }
    }
}

extension HackersPub.PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.SharedPost.Actor: ActorProtocol {}

extension HackersPub.PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.SharedPost.Medium: MediaProtocol {}
