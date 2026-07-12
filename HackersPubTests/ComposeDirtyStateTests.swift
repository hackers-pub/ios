@testable import HackersPub
import Testing

struct ComposeDirtyStateTests {
    @Test func automaticReplyMentionSeedKeepsUntouchedDraftClean() {
        var dirtyState = ComposeDirtyState(initialContent: "Existing draft")

        let content = dirtyState.applyReplyMentionSeed(
            handles: ["@alice", "@bob"],
            currentContent: "Existing draft",
            isCurrent: true
        )

        #expect(content == "@alice @bob Existing draft")
        #expect(dirtyState.baselineContent == "@alice @bob Existing draft")
        #expect(!dirtyState.isContentDirty(currentContent: content))
    }

    @Test func userTextBeforeReplySeedRemainsDirty() {
        var dirtyState = ComposeDirtyState(initialContent: "Existing draft")

        let content = dirtyState.applyReplyMentionSeed(
            handles: ["@alice"],
            currentContent: "User replacement",
            isCurrent: true
        )

        #expect(content == "@alice User replacement")
        #expect(dirtyState.baselineContent == "@alice Existing draft")
        #expect(dirtyState.isContentDirty(currentContent: content))
    }

    @Test func initialEditBaselineAbsorbsOnlyProgrammaticReplyPrefix() {
        var dirtyState = ComposeDirtyState(initialContent: "Persisted article edit")

        let content = dirtyState.applyReplyMentionSeed(
            handles: ["@alice"],
            currentContent: "Persisted article edit plus user text",
            isCurrent: true
        )

        #expect(content == "@alice Persisted article edit plus user text")
        #expect(dirtyState.baselineContent == "@alice Persisted article edit")
        #expect(dirtyState.isContentDirty(currentContent: content))
    }

    @Test func staleOrRepeatedReplySeedsDoNotDuplicateOrRollbackBaseline() {
        var dirtyState = ComposeDirtyState(initialContent: "Draft")

        let cancelledContent = dirtyState.applyReplyMentionSeed(
            handles: ["@stale"],
            currentContent: "Draft",
            isCurrent: false
        )
        #expect(cancelledContent == "Draft")
        #expect(dirtyState.baselineContent == "Draft")

        let seededContent = dirtyState.applyReplyMentionSeed(
            handles: ["@alice"],
            currentContent: cancelledContent,
            isCurrent: true
        )
        let repeatedContent = dirtyState.applyReplyMentionSeed(
            handles: ["@bob"],
            currentContent: seededContent,
            isCurrent: true
        )

        #expect(seededContent == "@alice Draft")
        #expect(repeatedContent == "@alice Draft")
        #expect(dirtyState.baselineContent == "@alice Draft")
    }

    @Test func photosStillBlockDismissalWhenTextIsClean() {
        let dirtyState = ComposeDirtyState(initialContent: "Draft")
        var presentation = ComposePresentationCoordinator()

        let action = presentation.requestDismiss(
            isContentDirty: dirtyState.isContentDirty(currentContent: "Draft"),
            hasPhotos: true,
            isBusy: false
        )

        #expect(action == .none)
        #expect(presentation.showsDiscardConfirmation)
    }
}
