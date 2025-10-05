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
