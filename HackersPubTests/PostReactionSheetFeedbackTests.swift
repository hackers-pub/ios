@testable import HackersPub
import Testing

struct PostReactionSheetFeedbackTests {
    @Test @MainActor func sheetKeepsLoadedReactorsVisibleAlongsideRetryableFeedback() {
        var infoRetryCount = 0
        var mutationRetryCount = 0
        let reactors = [
            ReactionGroupInfo(
                emoji: "🎉",
                customEmojiUrl: nil,
                reactors: [
                    ReactorInfo(
                        id: "actor",
                        name: "Actor",
                        handle: "@actor@example.com",
                        avatarUrl: ""
                    )
                ],
                totalCount: 1
            )
        ]

        let sheet = PostReactionSheetView(
            reactionGroups: [],
            reactionInfos: reactors,
            isLoadingReactionInfos: false,
            reactionInfosErrorMessage: "Offline",
            reactionMutationErrorMessage: "Unable to react",
            isSubmitting: false,
            onEmojiSelect: { _ in },
            onRetryReactionInfos: { infoRetryCount += 1 },
            onRetryReactionMutation: { mutationRetryCount += 1 },
            onReactorSelected: { _ in },
            onClose: {}
        )

        #expect(sheet.reactionInfos == reactors)
        #expect(sheet.reactionInfosErrorMessage == "Offline")
        #expect(sheet.reactionMutationErrorMessage == "Unable to react")

        sheet.onRetryReactionInfos()
        sheet.onRetryReactionMutation()

        #expect(infoRetryCount == 1)
        #expect(mutationRetryCount == 1)
    }
}
