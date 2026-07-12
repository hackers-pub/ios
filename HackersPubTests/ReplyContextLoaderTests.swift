import Foundation
@testable import HackersPub
import Testing

@MainActor
struct ReplyContextLoaderTests {
    @Test func locksReplyToTheOriginalPublicFollowersAndDirectVisibility() async {
        let publicContext = await loadContext(visibility: .case(.public))
        let followersContext = await loadContext(visibility: .case(.followers))
        let directContext = await loadContext(visibility: .case(.direct))

        #expect(publicContext?.visibility == .case(.public))
        #expect(followersContext?.visibility == .case(.followers))
        #expect(directContext?.visibility == .case(.direct))
    }

    @Test func loadsMultiplePagesWithinReplyContextLimits() async {
        var requestedCursors: [String?] = []
        let firstPageMentions = (1 ... 20).map { "@mention-\($0)" }
        let secondPageMentions = (21 ... 40).map { "@mention-\($0)" }

        let outcome = await loadReplyContext(
            postID: "post-id",
            currentViewerHandle: "@viewer",
            isCurrent: { true },
            fetchPage: { cursor in
                requestedCursors.append(cursor)
                if cursor == nil {
                    return page(
                        mentions: firstPageMentions,
                        hasNextPage: true,
                        endCursor: "cursor-20"
                    )
                }
                if cursor == "cursor-20" {
                    return page(
                        mentions: secondPageMentions,
                        hasNextPage: true,
                        endCursor: "cursor-40"
                    )
                }
                return page(
                    mentions: ["@mention-41"],
                    hasNextPage: false,
                    endCursor: "cursor-41"
                )
            }
        )

        #expect(
            context(from: outcome)?.mentionHandles
                == ["@author"] + firstPageMentions + secondPageMentions + ["@mention-41"]
        )
        #expect(requestedCursors == [nil, "cursor-20", "cursor-40"])
    }

    @Test func removesSelfAndDuplicateMentionHandlesInStableOrder() async {
        let outcome = await loadReplyContext(
            postID: "post-id",
            currentViewerHandle: "@viewer",
            isCurrent: { true },
            fetchPage: { _ in
                page(
                    authorHandle: "@Author",
                    mentions: ["@viewer", "@author", "@friend", "@FRIEND", "@other"],
                    hasNextPage: false,
                    endCursor: "cursor"
                )
            }
        )

        #expect(context(from: outcome)?.mentionHandles == ["@Author", "@friend", "@other"])
    }

    @Test func secondPageFailureKeepsReplyFailClosedAndCanRetry() async {
        var requestedCursors: [String?] = []
        let firstPage = page(mentions: ["@mention-1"], hasNextPage: true, endCursor: "cursor-1")

        let failed = await loadReplyContext(
            postID: "post-id",
            currentViewerHandle: nil,
            isCurrent: { true },
            fetchPage: { cursor in
                requestedCursors.append(cursor)
                if cursor == nil {
                    return firstPage
                }
                throw ReplyContextTestError.pageTwoFailed
            }
        )

        #expect(context(from: failed) == nil)
        #expect(didFail(failed))

        let retried = await loadReplyContext(
            postID: "post-id",
            currentViewerHandle: nil,
            isCurrent: { true },
            fetchPage: { cursor in
                requestedCursors.append(cursor)
                if cursor == nil {
                    return firstPage
                }
                return page(mentions: ["@mention-2"], hasNextPage: false, endCursor: "cursor-2")
            }
        )

        #expect(context(from: retried)?.mentionHandles == ["@author", "@mention-1", "@mention-2"])
        #expect(requestedCursors == [nil, "cursor-1", nil, "cursor-1"])
    }

    @Test func ignoresStaleAndCancelledReplyContextRequests() async {
        var fetchCount = 0
        let stale = await loadReplyContext(
            postID: "post-id",
            currentViewerHandle: nil,
            isCurrent: { false },
            fetchPage: { _ in
                fetchCount += 1
                return page(mentions: [], hasNextPage: false, endCursor: nil)
            }
        )

        #expect(stale == .ignored)
        #expect(fetchCount == 0)

        let cancelledTask = Task { @MainActor in
            await loadReplyContext(
                postID: "post-id",
                currentViewerHandle: nil,
                isCurrent: { true },
                fetchPage: { _ in
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                    return page(mentions: [], hasNextPage: false, endCursor: nil)
                }
            )
        }
        cancelledTask.cancel()

        let cancelled = await cancelledTask.value
        #expect(cancelled == .ignored)
    }

    @Test
    // swiftlint:disable:next function_body_length
    func noneVisibilityFailsClosedAndNeverDispatchesCreateNote() async {
        let contextOutcome = await loadReplyContext(
            postID: "post-id",
            currentViewerHandle: nil,
            isCurrent: { true },
            fetchPage: { _ in
                page(
                    visibility: .case(.none),
                    mentions: [],
                    hasNextPage: false,
                    endCursor: nil
                )
            }
        )

        let contextError: String?
        if case let .failed(message) = contextOutcome {
            contextError = message
        } else {
            contextError = nil
        }
        #expect(context(from: contextOutcome) == nil)
        #expect(
            contextError == NSLocalizedString(
                "compose.reply.contextUnavailable",
                comment: "Reply context unavailable"
            )
        )

        var mutationCallCount = 0
        let dispatcher = ComposeNoteDispatcher { _ in
            mutationCallCount += 1
            return .created(id: "unexpected")
        }

        let didRejectUnsupportedVisibility: Bool
        do {
            _ = try await dispatcher.submit(
                CreateNoteDispatchRequest(
                    content: "reply",
                    language: "en",
                    visibility: .case(.none),
                    media: [],
                    replyTargetID: "post-id",
                    quotedPostID: nil
                )
            )
            didRejectUnsupportedVisibility = false
        } catch ComposeNoteDispatchError.unsupportedVisibility {
            didRejectUnsupportedVisibility = true
        } catch {
            didRejectUnsupportedVisibility = false
        }

        #expect(didRejectUnsupportedVisibility)
        #expect(mutationCallCount == 0)
    }

    @Test func supportedReplyVisibilitiesReachTheTypedCreateNoteMutation() async throws {
        var mutations: [HackersPub.CreateNoteMutation] = []
        let dispatcher = ComposeNoteDispatcher { mutation in
            mutations.append(mutation)
            return .created(id: "created-\(mutations.count)")
        }
        let supportedVisibilities: [GraphQLEnum<HackersPub.PostVisibility>] = [
            .case(.public),
            .case(.unlisted),
            .case(.followers),
            .case(.direct)
        ]

        for visibility in supportedVisibilities {
            _ = try await dispatcher.submit(
                CreateNoteDispatchRequest(
                    content: "reply",
                    language: "en",
                    visibility: visibility,
                    media: [],
                    replyTargetID: "post-id",
                    quotedPostID: "quote-id"
                )
            )
        }

        #expect(mutations.map(\.visibility) == supportedVisibilities)
        #expect(mutations.map(\.content) == Array(repeating: "reply", count: 4))
        #expect(mutations.allSatisfy { $0.replyTargetId == .some("post-id") })
        #expect(mutations.allSatisfy { $0.quotedPostId == .some("quote-id") })
    }

    private func loadContext(visibility: GraphQLEnum<HackersPub.PostVisibility>) async -> ReplyContext? {
        let outcome = await loadReplyContext(
            postID: "post-id",
            currentViewerHandle: nil,
            isCurrent: { true },
            fetchPage: { _ in
                page(visibility: visibility, mentions: [], hasNextPage: false, endCursor: nil)
            }
        )
        return context(from: outcome)
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

    private enum ReplyContextTestError: Error {
        case pageTwoFailed
    }
}
