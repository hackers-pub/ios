import Foundation

struct PostEngagementState: Equatable {
    let target: PostEngagementTarget
    var hasShared: Bool
    var hasBookmarked: Bool
    var repliesCount: Int
    var reactionsCount: Int
    var sharesCount: Int
    var quotesCount: Int
    var reactionGroups: [ReactionGroupSnapshot]
    var isSharing = false
    var shareErrorMessage: String?
    private var shareGeneration = 0
    var reactionErrorMessage: String?
    private(set) var pendingReactionErrorMessage: String?

    init(post: some PostProtocol & ReactionCapablePostProtocol) {
        if let displayedPost = post.sharedPost {
            target = PostEngagementTarget(wrapperPostID: post.id, postID: displayedPost.id)
            hasShared = displayedPost.viewerHasShared
            hasBookmarked = displayedPost.viewerHasBookmarked
            repliesCount = displayedPost.engagementStats.replies
            reactionsCount = displayedPost.engagementStats.reactions
            sharesCount = displayedPost.engagementStats.shares
            quotesCount = displayedPost.engagementStats.quotes
            reactionGroups = []
        } else {
            target = PostEngagementTarget(wrapperPostID: post.id, postID: post.id)
            hasShared = post.viewerHasShared
            hasBookmarked = post.viewerHasBookmarked
            repliesCount = post.engagementStats.replies
            reactionsCount = post.engagementStats.reactions
            sharesCount = post.engagementStats.shares
            quotesCount = post.engagementStats.quotes
            reactionGroups = post.reactionGroupsSnapshot
        }
    }

    var viewerHasReacted: Bool {
        reactionGroups.contains(where: \.viewerHasReacted)
    }

    mutating func prepareReactionPicker() {
        reactionErrorMessage = nil
        pendingReactionErrorMessage = nil
    }

    mutating func deferReactionErrorUntilPickerDismissed(_ message: String) {
        reactionErrorMessage = nil
        pendingReactionErrorMessage = message
    }

    mutating func reactionPickerDidDismiss() {
        guard let pendingReactionErrorMessage else { return }
        reactionErrorMessage = pendingReactionErrorMessage
        self.pendingReactionErrorMessage = nil
    }

    mutating func beginShareToggle() -> PostShareAttempt? {
        guard !isSharing else { return nil }

        shareGeneration += 1
        let attempt = PostShareAttempt(
            targetPostID: target.postID,
            generation: shareGeneration,
            desiredHasShared: !hasShared,
            previousHasShared: hasShared,
            previousSharesCount: sharesCount
        )
        isSharing = true
        shareErrorMessage = nil
        hasShared = attempt.desiredHasShared
        sharesCount = max(0, sharesCount + (attempt.desiredHasShared ? 1 : -1))
        return attempt
    }

    mutating func completeShare(_ attempt: PostShareAttempt, hasShared: Bool, sharesCount: Int) {
        guard ownsShareAttempt(attempt) else { return }
        self.hasShared = hasShared
        self.sharesCount = max(0, sharesCount)
        isSharing = false
        shareErrorMessage = nil
    }

    mutating func failShare(_ attempt: PostShareAttempt, message: String) {
        guard ownsShareAttempt(attempt) else { return }
        restoreShareState(from: attempt)
        shareErrorMessage = message
    }

    mutating func cancelShare(_ attempt: PostShareAttempt) {
        guard ownsShareAttempt(attempt) else { return }
        restoreShareState(from: attempt)
        shareErrorMessage = nil
    }

    mutating func applyReaction(emoji: String, adding: Bool) {
        let existingGroup = ReactionGroupIndex.standardGroup(matching: emoji, in: reactionGroups)
        let insertionIndex = reactionGroups.firstIndex {
            guard let groupEmoji = $0.emoji else { return false }
            return ReactionGroupIndex.isEquivalentStandardEmoji(groupEmoji, emoji)
        }
        reactionGroups.removeAll {
            guard let groupEmoji = $0.emoji else { return false }
            return ReactionGroupIndex.isEquivalentStandardEmoji(groupEmoji, emoji)
        }

        if let group = existingGroup {
            let updatedCount = max(0, group.totalCount + (adding ? 1 : -1))
            if updatedCount > 0 {
                let mutationEmoji = adding ? emoji : group.emoji
                reactionGroups.insert(
                    ReactionGroupSnapshot(
                        id: "emoji:\(mutationEmoji ?? emoji)",
                        emoji: mutationEmoji,
                        customEmojiName: group.customEmojiName,
                        customEmojiImageUrl: group.customEmojiImageUrl,
                        totalCount: updatedCount,
                        viewerHasReacted: adding
                    ),
                    at: min(insertionIndex ?? reactionGroups.endIndex, reactionGroups.endIndex)
                )
            }
        } else if adding {
            reactionGroups.append(
                ReactionGroupSnapshot(
                    id: "emoji:\(emoji)", emoji: emoji, customEmojiName: nil,
                    customEmojiImageUrl: nil, totalCount: 1, viewerHasReacted: true
                )
            )
        }

        reactionsCount = max(0, reactionsCount + (adding ? 1 : -1))
    }

    func reactionRollbackSnapshot() -> ReactionRollbackSnapshot {
        ReactionRollbackSnapshot(reactionGroups: reactionGroups, reactionsCount: reactionsCount)
    }

    mutating func restoreReactionState(from snapshot: ReactionRollbackSnapshot) {
        reactionGroups = snapshot.reactionGroups
        reactionsCount = snapshot.reactionsCount
    }

    mutating func reconcileReactions(groups: [ReactionGroupSnapshot], totalCount: Int) {
        reactionGroups = groups
        reactionsCount = max(0, totalCount)
    }

    private func ownsShareAttempt(_ attempt: PostShareAttempt) -> Bool {
        target.postID == attempt.targetPostID && shareGeneration == attempt.generation
    }

    private mutating func restoreShareState(from attempt: PostShareAttempt) {
        hasShared = attempt.previousHasShared
        sharesCount = attempt.previousSharesCount
        isSharing = false
    }
}

struct ReactionRollbackSnapshot: Equatable {
    let reactionGroups: [ReactionGroupSnapshot]
    let reactionsCount: Int
}
