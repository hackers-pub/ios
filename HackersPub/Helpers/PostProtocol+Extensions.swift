import Foundation

// MARK: - SearchPost Extensions

extension HackersPub.SearchPostQuery.Data.SearchPost.Edge.Node: PostProtocol {
    typealias SharedPostType = HackersPub.SearchPostQuery.Data.SearchPost.Edge.Node.SharedPost

    var isArticle: Bool {
        // Temporarily disabled - just show all posts as regular posts
        return false
    }
}

extension HackersPub.SearchPostQuery.Data.SearchPost.Edge.Node.Actor: ActorProtocol {}

extension HackersPub.SearchPostQuery.Data.SearchPost.Edge.Node.Medium: MediaProtocol {}

extension HackersPub.SearchPostQuery.Data.SearchPost.Edge.Node.SharedPost: PostProtocol {
    typealias SharedPostType = HackersPub.SearchPostQuery.Data.SearchPost.Edge.Node.SharedPost
    var sharedPost: HackersPub.SearchPostQuery.Data.SearchPost.Edge.Node.SharedPost? { nil }

    var isArticle: Bool {
        // Temporarily disabled - just show all posts as regular posts
        return false
    }
}

extension HackersPub.SearchPostQuery.Data.SearchPost.Edge.Node.SharedPost.Actor: ActorProtocol {}

extension HackersPub.SearchPostQuery.Data.SearchPost.Edge.Node.SharedPost.Medium: MediaProtocol {}

// MARK: - ActorByHandle Extensions

extension HackersPub.ActorByHandleQuery.Data.ActorByHandle.Posts.Edge.Node: PostProtocol {
    typealias SharedPostType = HackersPub.ActorByHandleQuery.Data.ActorByHandle.Posts.Edge.Node.SharedPost

    var isArticle: Bool {
        // Temporarily disabled - just show all posts as regular posts
        return false
    }
}

extension HackersPub.ActorByHandleQuery.Data.ActorByHandle.Posts.Edge.Node.Actor: ActorProtocol {}

extension HackersPub.ActorByHandleQuery.Data.ActorByHandle.Posts.Edge.Node.Medium: MediaProtocol {}

extension HackersPub.ActorByHandleQuery.Data.ActorByHandle.Posts.Edge.Node.SharedPost: PostProtocol {
    typealias SharedPostType = HackersPub.ActorByHandleQuery.Data.ActorByHandle.Posts.Edge.Node.SharedPost
    var sharedPost: HackersPub.ActorByHandleQuery.Data.ActorByHandle.Posts.Edge.Node.SharedPost? { nil }

    var isArticle: Bool {
        // Temporarily disabled - just show all posts as regular posts
        return false
    }
}

extension HackersPub.ActorByHandleQuery.Data.ActorByHandle.Posts.Edge.Node.SharedPost.Actor: ActorProtocol {}

extension HackersPub.ActorByHandleQuery.Data.ActorByHandle.Posts.Edge.Node.SharedPost.Medium: MediaProtocol {}

extension HackersPub.ActorByHandleQuery.Data.ActorByHandle: Identifiable {}

// MARK: - Notifications Extensions

extension HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsMentionNotification.Post: PostProtocol {
    typealias SharedPostType = HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsMentionNotification.Post
    var sharedPost: SharedPostType? { nil }

    var isArticle: Bool {
        return __typename == "Article"
    }
}

extension HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsMentionNotification.Post.Actor: ActorProtocol {}

extension HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsMentionNotification.Post.Medium: MediaProtocol {}

extension HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsReplyNotification.Post: PostProtocol {
    typealias SharedPostType = HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsReplyNotification.Post
    var sharedPost: SharedPostType? { nil }

    var isArticle: Bool {
        return __typename == "Article"
    }
}

extension HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsReplyNotification.Post.Actor: ActorProtocol {}

extension HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsReplyNotification.Post.Medium: MediaProtocol {}

extension HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsQuoteNotification.Post: PostProtocol {
    typealias SharedPostType = HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsQuoteNotification.Post
    var sharedPost: SharedPostType? { nil }

    var isArticle: Bool {
        return __typename == "Article"
    }
}

extension HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsQuoteNotification.Post.Actor: ActorProtocol {}

extension HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsQuoteNotification.Post.Medium: MediaProtocol {}

extension HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsReactNotification.Post: PostProtocol {
    typealias SharedPostType = HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsReactNotification.Post
    var sharedPost: SharedPostType? { nil }

    var isArticle: Bool {
        return __typename == "Article"
    }
}

extension HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsReactNotification.Post.Actor: ActorProtocol {}

extension HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsReactNotification.Post.Medium: MediaProtocol {}

extension HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsShareNotification.Post: PostProtocol {
    typealias SharedPostType = HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsShareNotification.Post
    var sharedPost: SharedPostType? { nil }

    var isArticle: Bool {
        return __typename == "Article"
    }
}

extension HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsShareNotification.Post.Actor: ActorProtocol {}

extension HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsShareNotification.Post.Medium: MediaProtocol {}

// MARK: - PostDetail Extensions

extension HackersPub.PostDetailQuery.Data.Node.AsPost: PostProtocol {
    typealias SharedPostType = HackersPub.PostDetailQuery.Data.Node.AsPost.SharedPost

    var isArticle: Bool {
        return __typename == "Article"
    }
}

extension HackersPub.PostDetailQuery.Data.Node.AsPost.Actor: ActorProtocol {}

extension HackersPub.PostDetailQuery.Data.Node.AsPost.Medium: MediaProtocol {}

extension HackersPub.PostDetailQuery.Data.Node.AsPost.SharedPost: PostProtocol {
    typealias SharedPostType = HackersPub.PostDetailQuery.Data.Node.AsPost.SharedPost
    var sharedPost: SharedPostType? { nil }

    var isArticle: Bool {
        return __typename == "Article"
    }
}

extension HackersPub.PostDetailQuery.Data.Node.AsPost.SharedPost.Actor: ActorProtocol {}

extension HackersPub.PostDetailQuery.Data.Node.AsPost.SharedPost.Medium: MediaProtocol {}

// PostDetail Replies Extensions

extension HackersPub.PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node: PostProtocol {
    typealias SharedPostType = HackersPub.PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.SharedPost

    var isArticle: Bool {
        return __typename == "Article"
    }
}

extension HackersPub.PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.Actor: ActorProtocol {}

extension HackersPub.PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.Medium: MediaProtocol {}

extension HackersPub.PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.SharedPost: PostProtocol {
    typealias SharedPostType = HackersPub.PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.SharedPost
    var sharedPost: SharedPostType? { nil }

    var isArticle: Bool {
        return __typename == "Article"
    }
}

extension HackersPub.PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.SharedPost.Actor: ActorProtocol {}

extension HackersPub.PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node.SharedPost.Medium: MediaProtocol {}
