import Foundation
@testable import HackersPub
import Testing

@MainActor
struct NotificationPostPreviewTests {
    typealias MentionPost = HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsMentionNotification.Post
    typealias ReplyPost = HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsReplyNotification.Post
    typealias QuotePost = HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsQuoteNotification.Post
    typealias ReactPost = HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsReactNotification.Post
    typealias SharePost = HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsShareNotification.Post

    @Test("[POST-20][TL-10] generated notification posts use preview-only adapters")
    func generatedNotificationPostsUsePreviewOnlyAdapters() {
        requirePreviewOnlyAdapter(MentionPost.self)
        requirePreviewOnlyAdapter(ReplyPost.self)
        requirePreviewOnlyAdapter(QuotePost.self)
        requirePreviewOnlyAdapter(ReactPost.self)
        requirePreviewOnlyAdapter(SharePost.self)
    }

    @Test("[POST-20][TL-10] a stable post identifier exposes only the detail action")
    func stableIdentifierProducesDetailNavigationOnly() {
        let preview = NotificationPostPreview(
            postID: "  post-42  ",
            author: PostPreviewAuthor(
                name: "<strong>Ada</strong>",
                handle: "@ada@example.com",
                avatarURL: "https://example.com/ada.png"
            ),
            title: "Preview title",
            published: "2026-07-12T10:30:00Z",
            content: "<p>Fallback content</p>",
            summary: "<p>Summary content</p>",
            media: [
                PostPreviewMedia(
                    url: "https://example.com/full.png",
                    thumbnailURL: "https://example.com/thumb.png",
                    alt: "A test thumbnail"
                )
            ]
        )

        let presentation = NotificationPostPreviewPresentation(preview: preview)

        #expect(preview.route?.postID == "post-42")
        #expect(presentation.action == .openDetail(postID: "post-42"))
        #expect(presentation.title == "Preview title")
        #expect(presentation.body == "Summary content")
        #expect(presentation.authorName == "Ada")
        #expect(presentation.authorHandle == "@ada@example.com")
        #expect(presentation.published == "2026-07-12T10:30:00Z")
        #expect(presentation.thumbnailURL == URL(string: "https://example.com/thumb.png"))
        #expect(presentation.thumbnailAlt == "A test thumbnail")
    }

    @Test("[POST-20][TL-10] nil and partial preview fields degrade without a navigation action")
    func nilAndPartialFieldsAreSafeAndNonNavigableWithoutIdentity() {
        let blankIdentity = NotificationPostPreview(
            postID: " \n ",
            author: PostPreviewAuthor(name: nil, handle: " ", avatarURL: "not a URL"),
            title: " ",
            published: " ",
            content: "<p>   </p>",
            summary: nil,
            media: [PostPreviewMedia(url: "not a URL", thumbnailURL: nil, alt: " ")]
        )
        let invalidIdentity = NotificationPostPreview(
            postID: "post\u{0000}42",
            author: nil,
            title: nil,
            published: nil,
            content: nil,
            summary: nil,
            media: []
        )

        let blankPresentation = NotificationPostPreviewPresentation(preview: blankIdentity)
        let invalidPresentation = NotificationPostPreviewPresentation(preview: invalidIdentity)

        #expect(blankIdentity.route == nil)
        #expect(blankPresentation.action == nil)
        #expect(blankPresentation.title == nil)
        #expect(blankPresentation.body == nil)
        #expect(blankPresentation.authorName == nil)
        #expect(blankPresentation.published == nil)
        #expect(blankPresentation.thumbnailURL == nil)
        #expect(invalidIdentity.route == nil)
        #expect(invalidPresentation.action == nil)
    }

    @Test("[POST-20][TL-10] preview values cannot become mutation-capable posts")
    func previewValueDoesNotConformToMutationProtocols() {
        let preview = NotificationPostPreview(
            postID: "post-42",
            author: nil,
            title: nil,
            published: nil,
            content: nil,
            summary: nil,
            media: []
        )

        #expect(!(preview is any PostProtocol))
        #expect(!(preview is any ReactionCapablePostProtocol))
    }

    @Test("[POST-20][TL-10] avatar accessibility labels remove actor HTML and fall back to handles")
    func avatarAccessibilityLabelsUsePlainNamesOrHandles() {
        let actorNameWithCustomEmoji = #"<img alt=":wave:" src="https://e.t/w"><strong>Ada</strong>"#

        #expect(
            notificationActorAccessibilityLabel(name: actorNameWithCustomEmoji, handle: "@ada@example.com") == "Ada"
        )
        #expect(
            notificationActorAccessibilityLabel(
                name: #"<img class="emoji" alt=":wave:" src="https://example.com/wave.png">"#,
                handle: "@ada@example.com"
            ) == "@ada@example.com"
        )
    }

    private func requirePreviewOnlyAdapter<Source: NotificationPostPreviewSource>(_ sourceType: Source.Type) {
        let adapter: (Source) -> NotificationPostPreview = NotificationPostPreview.init
        _ = adapter

        requireNoMutationProtocolConformance(sourceType)
    }

    private func requireNoMutationProtocolConformance(_ sourceType: Any.Type) {
        #expect(!(sourceType is any PostProtocol.Type))
        #expect(!(sourceType is any ReactionCapablePostProtocol.Type))
    }
}
