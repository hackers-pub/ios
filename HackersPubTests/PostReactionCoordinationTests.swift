@testable import HackersPub
import Testing

struct PostReactionCoordinationTests {
    @Test func reactionCoordinatorRejectsReadThatPredatesOptimisticMutation() {
        var coordinator = PostReactionRequestCoordinator(targetPostID: "post")
        guard let read = coordinator.beginInfoLoad(),
              let mutation = coordinator.beginMutation()
        else {
            Issue.record("The coordinator must issue a read and mutation token.")
            return
        }

        #expect(!coordinator.shouldApply(read))
        let completion = coordinator.finish(mutation, outcome: .success)
        #expect(completion == .synchronize)

        guard let reconciliationRead = coordinator.beginInfoLoad() else {
            Issue.record("Successful mutations must permit a reconciliation read.")
            return
        }
        #expect(coordinator.shouldApply(reconciliationRead))
        #expect(!coordinator.shouldApply(read))
    }

    @Test func reactionCoordinatorAllowsMutationDuringReadAndMakesReconciliationMandatory() {
        var coordinator = PostReactionRequestCoordinator(targetPostID: "post")
        guard let staleRead = coordinator.beginInfoLoad(),
              let mutation = coordinator.beginMutation()
        else {
            Issue.record("The coordinator must issue a read and mutation token.")
            return
        }

        let completion = coordinator.finish(mutation, outcome: .success)
        #expect(completion == .synchronize)
        #expect(!coordinator.shouldApply(staleRead))
        let reconciliationRead = coordinator.beginInfoLoad()
        #expect(reconciliationRead != nil)
    }

    @Test func reactionCoordinatorRequiresFreshReadAfterRollback() {
        var coordinator = PostReactionRequestCoordinator(targetPostID: "post")
        guard let staleRead = coordinator.beginInfoLoad(),
              let mutation = coordinator.beginMutation()
        else {
            Issue.record("The coordinator must issue a read and mutation token.")
            return
        }

        let completion = coordinator.finish(mutation, outcome: .failure)
        #expect(completion == .rollbackWithError)
        #expect(!coordinator.shouldApply(staleRead))
        guard let rollbackRead = coordinator.beginInfoLoad() else {
            Issue.record("Rollback must permit a fresh read.")
            return
        }
        #expect(coordinator.shouldApply(rollbackRead))
    }

    @Test func reactionCoordinatorRejectsOutOfOrderCompletionsAfterRapidTargetSwitch() {
        var coordinator = PostReactionRequestCoordinator(targetPostID: "A")
        guard let firstA = coordinator.beginMutation() else {
            Issue.record("The coordinator must issue a mutation token.")
            return
        }
        coordinator.setTargetPostID("B")
        guard let secondTargetMutation = coordinator.beginMutation() else {
            Issue.record("The coordinator must issue a mutation token.")
            return
        }
        coordinator.setTargetPostID("A")
        guard let secondA = coordinator.beginMutation() else {
            Issue.record("The coordinator must issue a mutation token.")
            return
        }

        let firstCompletion = coordinator.finish(firstA, outcome: .failure)
        let secondCompletion = coordinator.finish(secondTargetMutation, outcome: .success)
        let finalCompletion = coordinator.finish(secondA, outcome: .cancelled)
        #expect(firstCompletion == .ignore)
        #expect(secondCompletion == .ignore)
        #expect(finalCompletion == .rollbackWithoutError)
    }

    @Test func reactionMutationRollsBackOptimisticStateOnlyForItsCurrentTarget() {
        var state = PostEngagementState(
            post: StubEngagementPost(
                id: "post",
                engagementStats: StubPostEngagementStats(replies: 0, reactions: 2, shares: 0, quotes: 0),
                reactionGroups: [
                    ReactionGroupSnapshot(
                        id: "heart",
                        emoji: "❤️",
                        customEmojiName: nil,
                        customEmojiImageUrl: nil,
                        totalCount: 2,
                        viewerHasReacted: false
                    )
                ]
            )
        )
        let rollback = state.reactionRollbackSnapshot()

        state.applyReaction(emoji: "❤️", adding: true)
        #expect(state.reactionsCount == 3)
        state.restoreReactionState(from: rollback)
        #expect(state.reactionsCount == 2)
        #expect(state.reactionGroups.first?.viewerHasReacted == false)
    }

    @Test func canonicalReactionAggregationIsOrderIndependentAndPreservesViewerMutationToken() {
        let groups = [
            ReactionGroupSnapshot(
                id: "plain-heart",
                emoji: "❤",
                customEmojiName: nil,
                customEmojiImageUrl: nil,
                totalCount: 2,
                viewerHasReacted: false
            ),
            ReactionGroupSnapshot(
                id: "emoji-heart",
                emoji: "❤️",
                customEmojiName: nil,
                customEmojiImageUrl: nil,
                totalCount: 2,
                viewerHasReacted: true
            ),
            ReactionGroupSnapshot(
                id: "duplicate-emoji-heart",
                emoji: "❤️",
                customEmojiName: nil,
                customEmojiImageUrl: nil,
                totalCount: 3,
                viewerHasReacted: false
            )
        ]

        guard let forward = ReactionGroupIndex.standardGroup(matching: "❤️", in: groups),
              let reverse = ReactionGroupIndex.standardGroup(matching: "❤️", in: Array(groups.reversed()))
        else {
            Issue.record("Canonical reaction groups must be present.")
            return
        }

        #expect(forward == reverse)
        #expect(forward.totalCount == 7)
        #expect(forward.emoji == "❤️")
        #expect(forward.viewerHasReacted)
        #expect(ReactionGroupIndex.mutationEmoji(for: "❤️", in: groups) == "❤️")
    }
}
