import Foundation
@testable import HackersPub
import Testing

@MainActor
struct ReplyContextPaginationLimitTests {
    @Test func failsWhenContinuallyAdvancingCursorsExceedReplyContextPageBudget() async {
        var requestedCursors: [String?] = []

        let outcome = await loadReplyContext(
            postID: "post-id",
            currentViewerHandle: nil,
            isCurrent: { true },
            fetchPage: { cursor in
                requestedCursors.append(cursor)
                let pageNumber = requestedCursors.count
                return page(
                    mentions: [],
                    hasNextPage: true,
                    endCursor: "cursor-\(pageNumber)"
                )
            }
        )

        let expectedCursors: [String?] = [nil]
            + (1 ..< replyContextPaginationLimits.maximumPageCount).map { Optional("cursor-\($0)") }

        #expect(context(from: outcome) == nil)
        #expect(didFail(outcome))
        #expect(requestedCursors == expectedCursors)
    }

    @Test func failsWhenContinuallyAdvancingCursorsExceedReplyContextMentionBudget() async {
        let mentionLimit = replyContextPaginationLimits.maximumMentionCount
        let firstPageCount = mentionLimit / 2
        let firstPageMentions = (1 ... firstPageCount).map { "@mention-\($0)" }
        let secondPageMentions = (firstPageCount + 1 ... mentionLimit).map { "@mention-\($0)" }
        var requestedCursors: [String?] = []

        let outcome = await loadReplyContext(
            postID: "post-id",
            currentViewerHandle: nil,
            isCurrent: { true },
            fetchPage: { cursor in
                requestedCursors.append(cursor)
                if cursor == nil {
                    return page(
                        mentions: firstPageMentions,
                        hasNextPage: true,
                        endCursor: "cursor-1"
                    )
                }
                if cursor == "cursor-1" {
                    return page(
                        mentions: secondPageMentions,
                        hasNextPage: true,
                        endCursor: "cursor-2"
                    )
                }
                return page(
                    mentions: ["@mention-\(mentionLimit + 1)"],
                    hasNextPage: false,
                    endCursor: "cursor-3"
                )
            }
        )

        #expect(context(from: outcome) == nil)
        #expect(didFail(outcome))
        #expect(requestedCursors == [nil, "cursor-1", "cursor-2"])
    }

    private func context(from outcome: ReplyContextLoadOutcome) -> ReplyContext? {
        guard case let .loaded(context) = outcome else { return nil }
        return context
    }

    private func didFail(_ outcome: ReplyContextLoadOutcome) -> Bool {
        guard case .failed = outcome else { return false }
        return true
    }

    private func page(
        visibility: GraphQLEnum<HackersPub.PostVisibility> = .case(.public),
        authorHandle: String = "@author",
        mentions: [String],
        hasNextPage: Bool,
        endCursor: String?
    ) -> ReplyContextPage {
        ReplyContextPage(
            postID: "post-id",
            visibility: visibility,
            authorHandle: authorHandle,
            mentionHandles: mentions,
            hasNextPage: hasNextPage,
            endCursor: endCursor
        )
    }
}
