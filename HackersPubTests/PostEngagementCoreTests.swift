// swiftlint:disable file_length
import CoreGraphics
@testable import HackersPub
import Testing

// swiftlint:disable:next type_body_length
struct PostEngagementCoreTests {
    @Test func originalPostUsesItselfForEveryEngagementRoute() {
        let post = StubEngagementPost(
            id: "original",
            engagementStats: StubPostEngagementStats(replies: 2, reactions: 3, shares: 4, quotes: 5),
            viewerHasShared: true,
            viewerHasBookmarked: true,
            reactionGroups: [
                ReactionGroupSnapshot(
                    id: "emoji:🎉",
                    emoji: "🎉",
                    customEmojiName: nil,
                    customEmojiImageUrl: nil,
                    totalCount: 3,
                    viewerHasReacted: true
                )
            ]
        )

        let state = PostEngagementState(post: post)

        #expect(state.target.wrapperPostID == "original")
        #expect(state.target.postID == "original")
        #expect(!state.target.isRepost)
        for route in PostEngagementRoute.allCases {
            #expect(state.target.postID(for: route) == "original")
        }
        #expect(state.repliesCount == 2)
        #expect(state.reactionsCount == 3)
        #expect(state.sharesCount == 4)
        #expect(state.quotesCount == 5)
        #expect(state.hasShared)
        #expect(state.hasBookmarked)
        #expect(state.reactionGroups == post.reactionGroupsSnapshot)
    }

    @Test func repostUsesDisplayedOriginalForEveryEngagementRouteAndStat() {
        let original = StubEngagementPost(
            id: "displayed-original",
            engagementStats: StubPostEngagementStats(replies: 7, reactions: 8, shares: 9, quotes: 10),
            viewerHasShared: true,
            viewerHasBookmarked: true
        )
        let wrapper = StubEngagementPost(
            id: "share-wrapper",
            sharedPost: original,
            engagementStats: StubPostEngagementStats(replies: 1, reactions: 1, shares: 1, quotes: 1),
            viewerHasShared: false,
            viewerHasBookmarked: false,
            reactionGroups: [
                ReactionGroupSnapshot(
                    id: "emoji:👀",
                    emoji: "👀",
                    customEmojiName: nil,
                    customEmojiImageUrl: nil,
                    totalCount: 99,
                    viewerHasReacted: true
                )
            ]
        )

        let state = PostEngagementState(post: wrapper)

        #expect(state.target.wrapperPostID == "share-wrapper")
        #expect(state.target.postID == "displayed-original")
        #expect(state.target.isRepost)
        for route in PostEngagementRoute.allCases {
            #expect(state.target.postID(for: route) == "displayed-original")
        }
        #expect(state.repliesCount == 7)
        #expect(state.reactionsCount == 8)
        #expect(state.sharesCount == 9)
        #expect(state.quotesCount == 10)
        #expect(state.hasShared)
        #expect(state.hasBookmarked)
        // Wrapper reaction groups describe the Announce activity, not the displayed original.
        #expect(state.reactionGroups.isEmpty)
    }

    @Test func sharedReactionReducerUpdatesCountAndSelectionWithoutViewSpecificLogic() {
        let post = StubEngagementPost(
            id: "post",
            engagementStats: StubPostEngagementStats(replies: 0, reactions: 1, shares: 0, quotes: 0),
            reactionGroups: [
                ReactionGroupSnapshot(
                    id: "emoji:❤️",
                    emoji: "❤️",
                    customEmojiName: nil,
                    customEmojiImageUrl: nil,
                    totalCount: 1,
                    viewerHasReacted: false
                )
            ]
        )
        var state = PostEngagementState(post: post)

        state.applyReaction(emoji: "❤️", adding: true)
        #expect(state.reactionsCount == 2)
        #expect(state.reactionGroups == [
            ReactionGroupSnapshot(
                id: "emoji:❤️",
                emoji: "❤️",
                customEmojiName: nil,
                customEmojiImageUrl: nil,
                totalCount: 2,
                viewerHasReacted: true
            )
        ])

        state.applyReaction(emoji: "❤️", adding: false)
        #expect(state.reactionsCount == 1)
        #expect(state.reactionGroups.first?.totalCount == 1)
        #expect(state.reactionGroups.first?.viewerHasReacted == false)
    }

    @Test func shareAttemptIsOptimisticAndAuthoritativePayloadWins() throws {
        let post = StubEngagementPost(
            id: "post",
            engagementStats: StubPostEngagementStats(replies: 0, reactions: 0, shares: 2, quotes: 0)
        )
        var state = PostEngagementState(post: post)
        state.shareErrorMessage = "stale"

        let pendingAttempt = state.beginShareToggle()
        let attempt = try #require(pendingAttempt)

        #expect(attempt.targetPostID == "post")
        #expect(attempt.desiredHasShared)
        #expect(state.hasShared)
        #expect(state.sharesCount == 3)
        #expect(state.isSharing)
        #expect(state.shareErrorMessage == nil)
        #expect(state.beginShareToggle() == nil)

        state.completeShare(attempt, hasShared: true, sharesCount: 7)
        #expect(state.hasShared)
        #expect(state.sharesCount == 7)
        #expect(!state.isSharing)
        #expect(state.shareErrorMessage == nil)
    }

    @Test func shareFailureRollsBackStateAndExposesRetryableError() throws {
        let post = StubEngagementPost(
            id: "post",
            engagementStats: StubPostEngagementStats(replies: 0, reactions: 0, shares: 4, quotes: 0),
            viewerHasShared: true
        )
        var state = PostEngagementState(post: post)

        let pendingAttempt = state.beginShareToggle()
        let attempt = try #require(pendingAttempt)
        #expect(!state.hasShared)
        #expect(state.sharesCount == 3)

        state.failShare(attempt, message: "Network unavailable")
        #expect(state.hasShared)
        #expect(state.sharesCount == 4)
        #expect(!state.isSharing)
        #expect(state.shareErrorMessage == "Network unavailable")
    }

    @Test func shareCancellationRollsBackWithoutPresentingAnError() throws {
        let post = StubEngagementPost(
            id: "post",
            engagementStats: StubPostEngagementStats(replies: 0, reactions: 0, shares: 0, quotes: 0)
        )
        var state = PostEngagementState(post: post)

        let pendingAttempt = state.beginShareToggle()
        let attempt = try #require(pendingAttempt)
        state.cancelShare(attempt)

        #expect(!state.hasShared)
        #expect(state.sharesCount == 0)
        #expect(!state.isSharing)
        #expect(state.shareErrorMessage == nil)
        #expect(PostEngagementMutationError.isCancellation(CancellationError()))
    }

    @Test func staleShareCompletionCannotOverwriteANewPostState() throws {
        let oldPost = StubEngagementPost(
            id: "old",
            engagementStats: StubPostEngagementStats(replies: 0, reactions: 0, shares: 0, quotes: 0)
        )
        var oldState = PostEngagementState(post: oldPost)
        let pendingOldAttempt = oldState.beginShareToggle()
        let oldAttempt = try #require(pendingOldAttempt)

        let newPost = StubEngagementPost(
            id: "new",
            engagementStats: StubPostEngagementStats(replies: 0, reactions: 0, shares: 12, quotes: 0),
            viewerHasShared: true
        )
        var newState = PostEngagementState(post: newPost)

        newState.completeShare(oldAttempt, hasShared: false, sharesCount: 0)
        #expect(newState.hasShared)
        #expect(newState.sharesCount == 12)
    }

    @Test func reactionFailureWaitsForPickerDismissalBeforePresentingAlert() {
        let post = StubEngagementPost(
            id: "post",
            engagementStats: StubPostEngagementStats(replies: 0, reactions: 0, shares: 0, quotes: 0)
        )
        var state = PostEngagementState(post: post)
        state.reactionErrorMessage = "stale"

        state.prepareReactionPicker()
        #expect(state.reactionErrorMessage == nil)
        #expect(state.pendingReactionErrorMessage == nil)

        state.deferReactionErrorUntilPickerDismissed("Unable to react")
        #expect(state.reactionErrorMessage == nil)
        #expect(state.pendingReactionErrorMessage == "Unable to react")

        state.reactionPickerDidDismiss()
        #expect(state.reactionErrorMessage == "Unable to react")
        #expect(state.pendingReactionErrorMessage == nil)

        state.reactionPickerDidDismiss()
        #expect(state.reactionErrorMessage == "Unable to react")
        #expect(state.pendingReactionErrorMessage == nil)
    }

    @Test func reactionInfoFailurePreservesPriorRowsAndRetryClearsOnlyTheError() {
        var state = ReactionInfoLoadState(items: ["reactor-a"])

        let beganFirstLoad = state.beginLoading()
        #expect(beganFirstLoad)
        state.fail(message: "Offline")
        #expect(state.items == ["reactor-a"])
        #expect(state.errorMessage == "Offline")
        #expect(!state.isLoading)

        let beganRetry = state.beginLoading()
        #expect(beganRetry)
        #expect(state.items == ["reactor-a"])
        #expect(state.errorMessage == nil)
        let beganDuplicateLoad = state.beginLoading()
        #expect(!beganDuplicateLoad)

        state.succeed(items: ["reactor-b"])
        #expect(state.items == ["reactor-b"])
        #expect(state.errorMessage == nil)
        #expect(!state.isLoading)
    }

    @Test func reactionInfoCancellationPreservesPriorRowsWithoutInventingEmptyState() {
        var state = ReactionInfoLoadState(items: ["reactor-a"])
        let beganLoad = state.beginLoading()
        #expect(beganLoad)

        state.cancel()

        #expect(state.items == ["reactor-a"])
        #expect(state.errorMessage == nil)
        #expect(!state.isLoading)
    }

    @Test func postDetailRefreshAndTranslationFailuresNeverBecomeBlockingContentErrors() {
        var state = PostDetailFailureState()

        state.failInitialLoad(message: "Initial load failed")
        #expect(state.blockingMessage == "Initial load failed")

        state.completeInitialLoad()
        state.failRefresh(message: "Refresh failed")
        state.failTranslation(message: "Translation failed")

        #expect(state.blockingMessage == nil)
        #expect(state.refreshMessage == "Refresh failed")
        #expect(state.translationMessage == "Translation failed")

        state.beginRefresh()
        #expect(state.refreshMessage == nil)
        #expect(state.translationMessage == "Translation failed")

        state.beginTranslation()
        #expect(state.translationMessage == nil)
    }

    @Test func successfulReactionMutationsRequestOnlyReactionDetailSynchronization() {
        let result = PostReactionMutationResult.success

        #expect(result.refreshScope == .reactionDetails)
    }

    @Test func engagementToolbarGestureDispatchesExactlyOneResolvedAction() {
        var actions: [EngagementToolbarGestureAction] = []

        EngagementToolbarGesturePolicy.dispatch(
            .longPress,
            onTap: { actions.append(.tap) },
            onLongPress: { actions.append(.longPress) }
        )
        #expect(actions == [.longPress])

        actions.removeAll()
        EngagementToolbarGesturePolicy.dispatch(
            .tap,
            onTap: { actions.append(.tap) },
            onLongPress: { actions.append(.longPress) }
        )
        #expect(actions == [.tap])
    }

    @Test func composeSuccessCreatesTypedEventsOnlyForReplies() {
        #expect(PostContentEvent.replyCreated(createdPostID: "note", replyTargetID: nil) == nil)
        #expect(
            PostContentEvent.replyCreated(createdPostID: "reply", replyTargetID: "parent")
                == .replyCreated(parentPostID: "parent", replyPostID: "reply")
        )
    }

    @Test func postDetailRoutesOnlyRelevantTypedContentEvents() {
        let replyIDs: Set = ["reply-a", "reply-b"]

        #expect(
            PostDetailContentEventRouter.route(
                .replyCreated(parentPostID: "post", replyPostID: "reply-c"),
                displayedPostID: "post",
                engagementTargetID: "post",
                loadedReplyIDs: replyIDs
            ) == .refreshReplies
        )
        #expect(
            PostDetailContentEventRouter.route(
                .replyCreated(parentPostID: "other", replyPostID: "reply-c"),
                displayedPostID: "post",
                engagementTargetID: "post",
                loadedReplyIDs: replyIDs
            ) == .none
        )
        #expect(
            PostDetailContentEventRouter.route(
                .postDeleted(postID: "reply-a"),
                displayedPostID: "post",
                engagementTargetID: "post",
                loadedReplyIDs: replyIDs
            ) == .removeReply("reply-a")
        )
        #expect(
            PostDetailContentEventRouter.route(
                .postDeleted(postID: "post"),
                displayedPostID: "post",
                engagementTargetID: "post",
                loadedReplyIDs: replyIDs
            ) == .dismiss
        )
    }

    @Test func postCopyIsLocalizedAndFormatsLoadFailures() {
        #expect(PostL10n.reposted != "post.reposted")
        #expect(PostL10n.sharesTitle != "post.shares.title")
        #expect(PostL10n.quotesTitle != "post.quotes.title")
        #expect(PostL10n.failedToLoadPost(details: "offline").contains("offline"))
        #expect(PostL10n.failedToLoadShares(details: "offline").contains("offline"))
        #expect(PostL10n.failedToLoadMoreShares(details: "offline").contains("offline"))
        #expect(PostL10n.failedToLoadQuotes(details: "offline").contains("offline"))
        #expect(PostL10n.failedToLoadMoreQuotes(details: "offline").contains("offline"))
    }

    @Test func deferredMenuWorkRunsOnTheMainActor() async {
        await withCheckedContinuation { continuation in
            DeferredMenuMainActor.perform {
                MainActor.preconditionIsolated()
                continuation.resume()
            }
        }
    }

    @Test func duplicateEmojiGroupsCollapseWithoutLosingSelection() throws {
        let groups = duplicateHeartGroups()

        let indexed = ReactionGroupIndex.standardGroupsByEmoji(groups)
        let reversed = ReactionGroupIndex.standardGroupsByEmoji(Array(groups.reversed()))
        let heart = try #require(indexed["❤️"])

        #expect(indexed.count == 1)
        #expect(heart.totalCount == 7)
        #expect(heart.viewerHasReacted)
        #expect(reversed["❤️"] == heart)

        let variationSelectorCollision = variationSelectorCollisionGroups()
        let canonical = ReactionGroupIndex.standardGroupsByEmoji(variationSelectorCollision)
        let canonicalReversed = ReactionGroupIndex.standardGroupsByEmoji(
            Array(variationSelectorCollision.reversed())
        )
        let canonicalHeart = try #require(canonical["❤️"])

        #expect(canonical.count == 1)
        #expect(canonicalHeart.totalCount == 10)
        #expect(canonicalHeart.viewerHasReacted)
        #expect(canonicalReversed["❤️"] == canonicalHeart)
    }

    @Test func reactionMutationUsesCanonicalMergedGroupState() throws {
        let groups = [
            ReactionGroupSnapshot(
                id: "plain-heart",
                emoji: "❤",
                customEmojiName: nil,
                customEmojiImageUrl: nil,
                totalCount: 5,
                viewerHasReacted: false
            ),
            ReactionGroupSnapshot(
                id: "emoji-heart",
                emoji: "❤️",
                customEmojiName: nil,
                customEmojiImageUrl: nil,
                totalCount: 3,
                viewerHasReacted: true
            )
        ]
        var state = PostEngagementState(
            post: StubEngagementPost(
                id: "post",
                engagementStats: StubPostEngagementStats(
                    replies: 0,
                    reactions: 8,
                    shares: 0,
                    quotes: 0
                ),
                reactionGroups: groups
            )
        )

        #expect(ReactionGroupIndex.viewerHasReacted(to: "❤️", in: groups))

        state.applyReaction(emoji: "❤️", adding: false)
        let removed = try #require(
            ReactionGroupIndex.standardGroupsByEmoji(state.reactionGroups)["❤️"]
        )
        #expect(removed.totalCount == 7)
        #expect(!removed.viewerHasReacted)
        #expect(state.reactionGroups.count == 1)
        #expect(state.reactionsCount == 7)

        state.applyReaction(emoji: "❤️", adding: true)
        let restored = try #require(
            ReactionGroupIndex.standardGroupsByEmoji(state.reactionGroups)["❤️"]
        )
        #expect(restored.totalCount == 8)
        #expect(restored.viewerHasReacted)
        #expect(state.reactionGroups.count == 1)
        #expect(state.reactionsCount == 8)
    }

    @Test func detailBookmarkResolutionPropagatesOnlyAuthoritativeSuccess() {
        var changes: [(String, Bool)] = []
        let notify: (String, Bool) -> Void = { changes.append(($0, $1)) }

        let authoritative = PostBookmarkChangePropagation.resolve(
            postID: "original",
            authoritativeState: false,
            fallbackState: true,
            onChange: notify
        )
        let rollback = PostBookmarkChangePropagation.resolve(
            postID: "original",
            authoritativeState: nil,
            fallbackState: true,
            onChange: notify
        )

        #expect(!authoritative)
        #expect(rollback)
        #expect(changes.map(\.0) == ["original"])
        #expect(changes.map(\.1) == [false])
    }

    @Test @MainActor func postDetailExposesTheBookmarkChangeConsumer() {
        var change: (String, Bool)?
        let detail = PostDetailView(postId: "wrapper") { change = ($0, $1) }

        detail.onBookmarkChanged?("original", false)

        #expect(detail.postId == "wrapper")
        #expect(change?.0 == "original")
        #expect(change?.1 == false)
    }

    @Test func engagementToolbarAccessibilityDescribesMetricAndAlternateAction() {
        let metadata = EngagementToolbarAccessibility(
            label: "Shares",
            count: 3,
            alternateActionName: "Show shares"
        )

        #expect(metadata.label == "Shares")
        #expect(metadata.value == "3")
        #expect(metadata.alternateActionName == "Show shares")
        #expect(EngagementToolbarAccessibility.minimumHitSize >= 44)
    }

    @Test func quotedPostNavigationWaitsForDismissAndConsumesOnce() {
        var navigation = PendingSheetPostNavigation()

        navigation.schedule(postID: "quoted-post")

        #expect(navigation.pendingPostID == "quoted-post")
        #expect(navigation.consume() == "quoted-post")
        #expect(navigation.pendingPostID == nil)
        #expect(navigation.consume() == nil)
    }

    @Test func contextMenuWidthUsesTheClosestAvailableContainerScope() {
        #expect(
            ContextMenuWidthResolver.resolve(
                proposedWidth: 180,
                localWidth: 240,
                parentWidth: 320,
                windowWidth: 700
            ) == 180
        )
        #expect(
            ContextMenuWidthResolver.resolve(
                proposedWidth: nil,
                localWidth: 240,
                parentWidth: 320,
                windowWidth: 700
            ) == 240
        )
        #expect(
            ContextMenuWidthResolver.resolve(
                proposedWidth: nil,
                localWidth: 0,
                parentWidth: 320,
                windowWidth: 700
            ) == 320
        )
        #expect(
            ContextMenuWidthResolver.resolve(
                proposedWidth: nil,
                localWidth: 0,
                parentWidth: nil,
                windowWidth: nil
            ) == 1
        )
    }

    @Test func guestAndAuthenticatedEngagementRoutesUseDisplayedOriginalIDs() {
        let original = StubEngagementPost(
            id: "original",
            engagementStats: StubPostEngagementStats(replies: 2, reactions: 0, shares: 3, quotes: 0)
        )
        let wrapper = StubEngagementPost(
            id: "wrapper",
            sharedPost: original,
            engagementStats: StubPostEngagementStats(replies: 0, reactions: 0, shares: 0, quotes: 0)
        )

        for state in [PostEngagementState(post: original), PostEngagementState(post: wrapper)] {
            let postID = state.target.postID

            assertReplyAccessActions(for: postID)
            assertShareAccessActions(for: postID)
        }
    }

    @Test func detailReplyReadPolicyRefreshesMissingOrFailedPublicReplies() {
        #expect(
            PostDetailReplyReadPolicy.action(
                hasPost: false,
                loadedReplyCount: 0,
                totalReplyCount: 2,
                hasRefreshFailure: false
            ) == .reloadPost
        )
        #expect(
            PostDetailReplyReadPolicy.action(
                hasPost: true,
                loadedReplyCount: 0,
                totalReplyCount: 2,
                hasRefreshFailure: false
            ) == .refreshReplies
        )
        #expect(
            PostDetailReplyReadPolicy.action(
                hasPost: true,
                loadedReplyCount: 2,
                totalReplyCount: 2,
                hasRefreshFailure: true
            ) == .refreshReplies
        )
        #expect(
            PostDetailReplyReadPolicy.action(
                hasPost: true,
                loadedReplyCount: 2,
                totalReplyCount: 2,
                hasRefreshFailure: false
            ) == .scroll
        )
    }
}

private func duplicateHeartGroups() -> [ReactionGroupSnapshot] {
    [
        ReactionGroupSnapshot(
            id: "first-heart",
            emoji: "❤️",
            customEmojiName: nil,
            customEmojiImageUrl: nil,
            totalCount: 2,
            viewerHasReacted: true
        ),
        ReactionGroupSnapshot(
            id: "second-heart",
            emoji: "❤️",
            customEmojiName: nil,
            customEmojiImageUrl: nil,
            totalCount: 5,
            viewerHasReacted: false
        ),
        ReactionGroupSnapshot(
            id: "custom",
            emoji: nil,
            customEmojiName: "party-parrot",
            customEmojiImageUrl: nil,
            totalCount: 9,
            viewerHasReacted: true
        )
    ]
}

private func variationSelectorCollisionGroups() -> [ReactionGroupSnapshot] {
    [
        ReactionGroupSnapshot(
            id: "plain-heart",
            emoji: "❤",
            customEmojiName: nil,
            customEmojiImageUrl: nil,
            totalCount: 7,
            viewerHasReacted: false
        ),
        ReactionGroupSnapshot(
            id: "emoji-heart",
            emoji: "❤️",
            customEmojiName: nil,
            customEmojiImageUrl: nil,
            totalCount: 3,
            viewerHasReacted: true
        )
    ]
}

private func assertReplyAccessActions(for postID: String) {
    #expect(
        PostEngagementAccessPolicy.reply(isAuthenticated: false, postID: postID)
            == .viewReplies(postID: "original")
    )
    #expect(
        PostEngagementAccessPolicy.reply(isAuthenticated: true, postID: postID)
            == .composeReply(postID: "original")
    )
}

private func assertShareAccessActions(for postID: String) {
    #expect(
        PostEngagementAccessPolicy.share(
            isAuthenticated: false,
            actionsSwapped: false,
            isAlternateAction: false,
            postID: postID
        ) == .viewShares(postID: "original")
    )
    #expect(
        PostEngagementAccessPolicy.share(
            isAuthenticated: false,
            actionsSwapped: true,
            isAlternateAction: true,
            postID: postID
        ) == .viewShares(postID: "original")
    )
    #expect(
        PostEngagementAccessPolicy.share(
            isAuthenticated: true,
            actionsSwapped: false,
            isAlternateAction: false,
            postID: postID
        ) == .toggleShare(postID: "original")
    )
    #expect(
        PostEngagementAccessPolicy.share(
            isAuthenticated: true,
            actionsSwapped: false,
            isAlternateAction: true,
            postID: postID
        ) == .viewShares(postID: "original")
    )
    #expect(
        PostEngagementAccessPolicy.share(
            isAuthenticated: true,
            actionsSwapped: true,
            isAlternateAction: false,
            postID: postID
        ) == .viewShares(postID: "original")
    )
    #expect(
        PostEngagementAccessPolicy.share(
            isAuthenticated: true,
            actionsSwapped: true,
            isAlternateAction: true,
            postID: postID
        ) == .toggleShare(postID: "original")
    )
}
