@testable import HackersPub
import Testing

@MainActor
struct PublishedArticleMediaAttachmentTests {
    @Test func typedDispatcherBuildsTheProductionSourceAttachmentMutation() async throws {
        let target = PublishedArticleEditTarget(
            articleId: "global-article-id",
            articleSourceId: "article-source-uuid"
        )
        var dispatchedMutations: [HackersPub.AttachArticleSourceMediumMutation] = []
        var insertedKey: String?
        let dispatcher = ArticleSourceMediumDispatcher { mutation in
            dispatchedMutations.append(mutation)
            return "server-attached-key"
        }

        try await attachPublishedArticleMedium(
            target: target,
            mediumId: "medium-uuid",
            key: "requested-key",
            attach: dispatcher.attach,
            insertMarkdown: { insertedKey = $0 }
        )

        #expect(dispatchedMutations.count == 1)
        #expect(dispatchedMutations[0].articleSourceId == "article-source-uuid")
        #expect(dispatchedMutations[0].mediumId == "medium-uuid")
        #expect(dispatchedMutations[0].key == .some("requested-key"))
        #expect(insertedKey == "server-attached-key")
    }

    @Test func usesSourceUUIDForAttachmentBeforeInsertingMarkdown() async throws {
        let target = PublishedArticleEditTarget(
            articleId: "global-article-id",
            articleSourceId: "article-source-uuid"
        )
        var attachmentRequest: ArticleSourceMediumAttachment?
        var events: [String] = []

        try await attachPublishedArticleMedium(
            target: target,
            mediumId: "medium-uuid",
            key: "requested-key",
            attach: { request in
                events.append("attach")
                attachmentRequest = request
                return "attached-key"
            },
            insertMarkdown: { key in
                events.append("markdown:\(key)")
            }
        )

        #expect(target.articleId == "global-article-id")
        #expect(
            attachmentRequest == ArticleSourceMediumAttachment(
                articleSourceId: "article-source-uuid",
                mediumId: "medium-uuid",
                key: "requested-key"
            )
        )
        #expect(events == ["attach", "markdown:attached-key"])
    }

    @Test func doesNotInsertMarkdownWhenSourceAttachmentFails() async {
        let target = PublishedArticleEditTarget(
            articleId: "global-article-id",
            articleSourceId: "article-source-uuid"
        )
        var events: [String] = []
        var didThrow = false

        do {
            try await attachPublishedArticleMedium(
                target: target,
                mediumId: "medium-uuid",
                key: "requested-key",
                attach: { _ in
                    events.append("attach")
                    throw AttachmentFailure.rejected
                },
                insertMarkdown: { _ in
                    events.append("markdown")
                }
            )
        } catch {
            didThrow = true
            #expect(error is AttachmentFailure)
        }

        #expect(didThrow)
        #expect(events == ["attach"])
    }

    private enum AttachmentFailure: Error {
        case rejected
    }
}
