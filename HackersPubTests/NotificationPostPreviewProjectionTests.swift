@_spi(Unsafe) import ApolloAPI
import Foundation
@testable import HackersPub
import Testing

@MainActor
struct NotificationPostPreviewProjectionTests {
    typealias MentionPost = HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsMentionNotification.Post
    typealias ReplyPost = HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsReplyNotification.Post
    typealias QuotePost = HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsQuoteNotification.Post
    typealias ReactPost = HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsReactNotification.Post
    typealias SharePost = HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsShareNotification.Post
    typealias PollEndedPost = HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsPollEndedNotification.Post
    typealias SharedPostUpdatedPost = HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsSharedPostUpdatedNotification.Post
    typealias QuotedPostUpdatedPost = HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsQuotedPostUpdatedNotification.Post

    @Test("Notifications query selects every server-defined notification type")
    func notificationsQuerySelectsEveryNotificationType() throws {
        let root = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let operation = try String(
            contentsOf: root.appending(path: "operation.graphql"),
            encoding: .utf8
        )
        let requiredTypes = [
            "PollEndedNotification",
            "SharedPostUpdatedNotification",
            "QuotedPostUpdatedNotification",
            "OrganizationInvitationNotification",
            "OrganizationConversionRequestNotification",
        ]

        for type in requiredTypes {
            #expect(operation.contains("... on \(type)"))
        }
    }

    @Test("[POST-20][TL-10] mention notification previews project generated values")
    func mentionProjectionUsesGeneratedPostValues() {
        assertProjection(
            makePost(MentionPost.self, fixture: .mention),
            expected: .mention
        )
    }

    @Test("[POST-20][TL-10] reply notification previews fall back to generated excerpts")
    func replyProjectionFallsBackToGeneratedExcerpt() {
        assertProjection(
            makePost(ReplyPost.self, fixture: .reply),
            expected: .reply
        )
    }

    @Test("[POST-20][TL-10] quote notification previews project generated values")
    func quoteProjectionUsesGeneratedPostValues() {
        assertProjection(
            makePost(QuotePost.self, fixture: .quote),
            expected: .quote
        )
    }

    @Test("[POST-20][TL-10] react notification previews preserve actor fallback")
    func reactProjectionUsesGeneratedActorHandleFallback() {
        assertProjection(
            makePost(ReactPost.self, fixture: .react),
            expected: .react
        )
    }

    @Test("[POST-20][TL-10] share notification previews project generated values")
    func shareProjectionUsesGeneratedPostValues() {
        assertProjection(
            makePost(SharePost.self, fixture: .share),
            expected: .share
        )
    }

    @Test("Poll-ended notification previews project generated values")
    func pollEndedProjectionUsesGeneratedPostValues() {
        assertProjection(
            makePost(PollEndedPost.self, fixture: .pollEnded),
            expected: .pollEnded
        )
    }

    @Test("Shared-post-updated notification previews project generated values")
    func sharedPostUpdatedProjectionUsesGeneratedPostValues() {
        assertProjection(
            makePost(SharedPostUpdatedPost.self, fixture: .sharedPostUpdated),
            expected: .sharedPostUpdated
        )
    }

    @Test("Quoted-post-updated notification previews project generated values")
    func quotedPostUpdatedProjectionUsesGeneratedPostValues() {
        assertProjection(
            makePost(QuotedPostUpdatedPost.self, fixture: .quotedPostUpdated),
            expected: .quotedPostUpdated
        )
    }

    private func assertProjection<Source: NotificationPostPreviewSource>(
        _ source: Source,
        expected: PreviewExpectation
    ) {
        let preview = NotificationPostPreview(source)
        let presentation = NotificationPostPreviewPresentation(preview: preview)

        #expect(preview.route?.postID == expected.postID)
        #expect(presentation.action == .openDetail(postID: expected.postID))
        #expect(presentation.authorName == expected.authorName)
        #expect(presentation.authorHandle == expected.authorHandle)
        #expect(presentation.title == expected.title)
        #expect(presentation.body == expected.body)
        #expect(presentation.thumbnailURL == expected.thumbnailURL.flatMap(URL.init(string:)))
        #expect(presentation.thumbnailAlt == expected.thumbnailAlt)
    }

    private func makePost<Source: SelectionSet>(
        _ source: Source.Type,
        fixture: NotificationPostFixture
    ) -> Source {
        var post: [String: DataDict.FieldValue] = [:]
        post["__typename"] = "Note"
        post["id"] = fixture.postID
        post["published"] = "2026-07-12T10:30:00Z"
        post["content"] = fixture.content
        post["media"] = [media(thumbnailURL: fixture.thumbnailURL, alt: fixture.mediaAlt)]
        post["actor"] = actor(name: fixture.actorName, handle: fixture.actorHandle)
        if let title = fixture.title {
            post["name"] = title
        }
        if let summary = fixture.summary {
            post["summary"] = summary
        }

        return Source(_dataDict: DataDict(
            data: post,
            fulfilledFragments: [ObjectIdentifier(source)]
        ))
    }

    private func actor(name: String?, handle: String) -> DataDict {
        var data: [String: DataDict.FieldValue] = [:]
        data["__typename"] = "Actor"
        data["id"] = "actor-id"
        data["handle"] = handle
        data["avatarUrl"] = "https://example.com/avatar.jpg"
        if let name {
            data["name"] = name
        }
        return DataDict(data: data, fulfilledFragments: [])
    }

    private func media(thumbnailURL: String?, alt: String?) -> DataDict {
        var data: [String: DataDict.FieldValue] = [:]
        data["__typename"] = "PostMedium"
        data["url"] = "https://example.com/reply-full.jpg"
        if let thumbnailURL {
            data["thumbnailUrl"] = thumbnailURL
        }
        if let alt {
            data["alt"] = alt
        }
        return DataDict(data: data, fulfilledFragments: [])
    }
}

private struct NotificationPostFixture {
    let postID: String
    let actorName: String?
    let actorHandle: String
    let title: String?
    let summary: String?
    let content: String
    let thumbnailURL: String?
    let mediaAlt: String?
}

private extension NotificationPostFixture {
    static let mention = NotificationPostFixture(
        postID: "mention-wrapper",
        actorName: "<strong>Mention Ada</strong>",
        actorHandle: "@mention@example.com",
        title: "Mention title",
        summary: "<p>Mention summary</p>",
        content: "<p>Mention excerpt</p>",
        thumbnailURL: "https://example.com/mention-thumb.jpg",
        mediaAlt: "Mention image"
    )
    static let reply = NotificationPostFixture(
        postID: "reply-wrapper",
        actorName: "<em>Reply Bea</em>",
        actorHandle: "@reply@example.com",
        title: "Reply title",
        summary: nil,
        content: "<p>Reply excerpt</p>",
        thumbnailURL: nil,
        mediaAlt: "Reply image"
    )
    static let quote = NotificationPostFixture(
        postID: "quote-wrapper",
        actorName: "<span>Quote Cyd</span>",
        actorHandle: "@quote@example.com",
        title: "<strong>Quote title</strong>",
        summary: "<p>Quote summary</p>",
        content: "<p>Quote excerpt</p>",
        thumbnailURL: "https://example.com/quote-thumb.jpg",
        mediaAlt: "Quote image"
    )
    static let react = NotificationPostFixture(
        postID: "react-wrapper",
        actorName: nil,
        actorHandle: "@react@example.com",
        title: nil,
        summary: nil,
        content: "<p>React excerpt</p>",
        thumbnailURL: "https://example.com/react-thumb.jpg",
        mediaAlt: nil
    )
    static let share = NotificationPostFixture(
        postID: "share-wrapper",
        actorName: "<strong>Share Dee</strong>",
        actorHandle: "@share@example.com",
        title: "Share title",
        summary: "<p>Share summary</p>",
        content: "<p>Share excerpt</p>",
        thumbnailURL: "https://example.com/share-thumb.jpg",
        mediaAlt: "Share image"
    )
    static let pollEnded = NotificationPostFixture(
        postID: "poll-ended-wrapper",
        actorName: "<strong>Poll Ada</strong>",
        actorHandle: "@poll@example.com",
        title: "Favorite language?",
        summary: "<p>Poll results</p>",
        content: "<p>Poll content</p>",
        thumbnailURL: nil,
        mediaAlt: nil
    )
    static let sharedPostUpdated = NotificationPostFixture(
        postID: "shared-updated-wrapper",
        actorName: "<strong>Shared Bea</strong>",
        actorHandle: "@shared@example.com",
        title: nil,
        summary: nil,
        content: "<p>Updated shared post</p>",
        thumbnailURL: "https://example.com/shared-updated-thumb.jpg",
        mediaAlt: "Updated shared image"
    )
    static let quotedPostUpdated = NotificationPostFixture(
        postID: "quoted-updated-wrapper",
        actorName: "<strong>Quoted Cyd</strong>",
        actorHandle: "@quoted@example.com",
        title: "Updated quoted post",
        summary: "<p>Updated quote summary</p>",
        content: "<p>Updated quote content</p>",
        thumbnailURL: nil,
        mediaAlt: "Updated quote image"
    )
}

private struct PreviewExpectation {
    let postID: String
    let authorName: String?
    let authorHandle: String?
    let title: String?
    let body: String?
    let thumbnailURL: String?
    let thumbnailAlt: String?
}

private extension PreviewExpectation {
    static let mention = PreviewExpectation(
        postID: "mention-wrapper",
        authorName: "Mention Ada",
        authorHandle: "@mention@example.com",
        title: "Mention title",
        body: "Mention summary",
        thumbnailURL: "https://example.com/mention-thumb.jpg",
        thumbnailAlt: "Mention image"
    )
    static let reply = PreviewExpectation(
        postID: "reply-wrapper",
        authorName: "Reply Bea",
        authorHandle: "@reply@example.com",
        title: "Reply title",
        body: "Reply excerpt",
        thumbnailURL: "https://example.com/reply-full.jpg",
        thumbnailAlt: "Reply image"
    )
    static let quote = PreviewExpectation(
        postID: "quote-wrapper",
        authorName: "Quote Cyd",
        authorHandle: "@quote@example.com",
        title: "Quote title",
        body: "Quote summary",
        thumbnailURL: "https://example.com/quote-thumb.jpg",
        thumbnailAlt: "Quote image"
    )
    static let react = PreviewExpectation(
        postID: "react-wrapper",
        authorName: "@react@example.com",
        authorHandle: nil,
        title: nil,
        body: "React excerpt",
        thumbnailURL: "https://example.com/react-thumb.jpg",
        thumbnailAlt: nil
    )
    static let share = PreviewExpectation(
        postID: "share-wrapper",
        authorName: "Share Dee",
        authorHandle: "@share@example.com",
        title: "Share title",
        body: "Share summary",
        thumbnailURL: "https://example.com/share-thumb.jpg",
        thumbnailAlt: "Share image"
    )
    static let pollEnded = PreviewExpectation(
        postID: "poll-ended-wrapper",
        authorName: "Poll Ada",
        authorHandle: "@poll@example.com",
        title: "Favorite language?",
        body: "Poll results",
        thumbnailURL: "https://example.com/reply-full.jpg",
        thumbnailAlt: nil
    )
    static let sharedPostUpdated = PreviewExpectation(
        postID: "shared-updated-wrapper",
        authorName: "Shared Bea",
        authorHandle: "@shared@example.com",
        title: nil,
        body: "Updated shared post",
        thumbnailURL: "https://example.com/shared-updated-thumb.jpg",
        thumbnailAlt: "Updated shared image"
    )
    static let quotedPostUpdated = PreviewExpectation(
        postID: "quoted-updated-wrapper",
        authorName: "Quoted Cyd",
        authorHandle: "@quoted@example.com",
        title: "Updated quoted post",
        body: "Updated quote summary",
        thumbnailURL: "https://example.com/reply-full.jpg",
        thumbnailAlt: "Updated quote image"
    )
}
