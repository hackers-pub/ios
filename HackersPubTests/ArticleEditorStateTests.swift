import Foundation
@testable import HackersPub
import Testing

private func articleSnapshot(
    title: String = "Loaded title",
    content: String = "Loaded content",
    tags: [String] = ["swift"],
    slug: String = "loaded-title",
    language: String = "en",
    allowLlmTranslation: Bool = true,
    pendingPhotos: [ArticlePendingPhotoSnapshot] = [],
    publishedMediumIDs: [String] = []
) -> ArticleEditorSnapshot {
    ArticleEditorSnapshot(
        title: title,
        content: content,
        tags: tags,
        slug: slug,
        language: language,
        allowLlmTranslation: allowLlmTranslation,
        pendingPhotos: pendingPhotos,
        publishedMediumIDs: publishedMediumIDs
    )
}

struct ArticleEditorChangeTrackerTests {
    @Test func baselineTracksNewDraftAndSeedEditsAcrossAllPersistedIntent() {
        let baseline = articleSnapshot()
        var tracker = ArticleEditorChangeTracker()

        tracker.recordBaseline(baseline)

        #expect(!tracker.hasChanges(comparedTo: baseline))
        #expect(tracker.hasChanges(comparedTo: articleSnapshot(title: "Changed title")))
        #expect(tracker.hasChanges(comparedTo: articleSnapshot(content: "Changed content")))
        #expect(tracker.hasChanges(comparedTo: articleSnapshot(tags: ["swift", "ios"])))
        #expect(tracker.hasChanges(comparedTo: articleSnapshot(slug: "custom-slug")))
        #expect(tracker.hasChanges(comparedTo: articleSnapshot(language: "ko")))
        #expect(tracker.hasChanges(comparedTo: articleSnapshot(allowLlmTranslation: false)))
        #expect(tracker.hasChanges(comparedTo: articleSnapshot(
            pendingPhotos: [ArticlePendingPhotoSnapshot(id: UUID(), alt: "Diagram")]
        )))
        #expect(tracker.hasChanges(comparedTo: articleSnapshot(publishedMediumIDs: ["medium-id"])))
    }
}

@MainActor
struct ArticleEditorMutationCoordinatorTests {
    @Test func delayedSaveCannotCommitOrDismissAfterTheRevisionChanges() async {
        let coordinator = ArticleEditorMutationCoordinator()
        let suspension = ControlledArticleOperation<ArticleMutationResponse<ArticleSavedDraft>>()
        var current = articleSnapshot()
        var mutationCalls = 0
        var commits = 0

        let task = Task {
            await coordinator.save(
                snapshot: current,
                currentSnapshot: { current },
                operation: {
                    mutationCalls += 1
                    return await suspension.run()
                }
            )
        }
        await suspension.waitUntilStarted()
        current = articleSnapshot(content: "Edited while saving")
        suspension.resume(returning: .success(ArticleSavedDraft(id: "draft-id", uuid: "draft-uuid")))

        let result = await task.value
        if case .current = result {
            commits += 1
        }

        #expect(mutationCalls == 1)
        #expect(commits == 0)
        guard case .stale = result else {
            Issue.record("Expected a stale save result")
            return
        }
    }

    @Test func twoRapidSavesInvokeTheMutationOnlyOnce() async {
        let coordinator = ArticleEditorMutationCoordinator()
        let suspension = ControlledArticleOperation<ArticleMutationResponse<ArticleSavedDraft>>()
        let snapshot = articleSnapshot()
        var mutationCalls = 0

        let first = Task {
            await coordinator.save(
                snapshot: snapshot,
                currentSnapshot: { snapshot },
                operation: {
                    mutationCalls += 1
                    return await suspension.run()
                }
            )
        }
        await suspension.waitUntilStarted()

        let second = await coordinator.save(
            snapshot: snapshot,
            currentSnapshot: { snapshot },
            operation: {
                mutationCalls += 1
                return .success(ArticleSavedDraft(id: "duplicate", uuid: "duplicate"))
            }
        )

        suspension.resume(returning: .success(ArticleSavedDraft(id: "draft-id", uuid: "draft-uuid")))
        _ = await first.value

        #expect(mutationCalls == 1)
        guard case .blocked = second else {
            Issue.record("Expected the second save to be blocked")
            return
        }
    }

    @Test func revisionChangeDuringDraftSavePreventsThePublishMutation() async {
        let coordinator = ArticleEditorMutationCoordinator()
        let suspension = ControlledArticleOperation<ArticleMutationResponse<ArticleSavedDraft>>()
        var current = articleSnapshot()
        var publishCalls = 0

        let task = Task {
            await coordinator.publish(
                snapshot: current,
                currentSnapshot: { current },
                saveDraft: {
                    await suspension.run()
                },
                publishDraft: { _ in
                    publishCalls += 1
                    return .success(())
                }
            )
        }
        await suspension.waitUntilStarted()
        current = articleSnapshot(slug: "changed-after-submit")
        suspension.resume(returning: .success(ArticleSavedDraft(id: "draft-id", uuid: "draft-uuid")))

        let result = await task.value

        #expect(publishCalls == 0)
        guard case .stale = result else {
            Issue.record("Expected the publish workflow to become stale")
            return
        }
    }
}

@MainActor
private final class ControlledArticleOperation<Value> {
    private var resultContinuation: CheckedContinuation<Value, Never>?
    private var startContinuations: [CheckedContinuation<Void, Never>] = []
    private var started = false

    func run() async -> Value {
        started = true
        let waiters = startContinuations
        startContinuations.removeAll()
        waiters.forEach { $0.resume() }
        return await withCheckedContinuation { continuation in
            resultContinuation = continuation
        }
    }

    func waitUntilStarted() async {
        guard !started else { return }
        await withCheckedContinuation { continuation in
            startContinuations.append(continuation)
        }
    }

    func resume(returning value: Value) {
        resultContinuation?.resume(returning: value)
        resultContinuation = nil
    }
}

struct ArticlePhotoUploadQueueTests {
    @Test func completedPhotosLeaveThePendingQueueBeforeALaterUploadFails() {
        let first = UUID()
        let second = UUID()
        let failing = UUID()
        var queue = ArticlePhotoUploadQueue(attachmentIDs: [first, second, failing])

        queue.markSucceeded(first)
        queue.markSucceeded(second)

        #expect(!queue.isPending(first))
        #expect(!queue.isPending(second))
        #expect(queue.isPending(failing))
    }
}

@MainActor
struct ArticlePhotoUploadCoordinatorTests {
    @Test func attachmentMutationIsRejectedWhileAnUploadIsSuspended() async {
        let coordinator = ArticlePhotoUploadCoordinator()
        let suspension = ControlledArticleOperation<Void>()
        let first = UUID()
        let second = UUID()
        var attachmentIDs = [first, second]
        var uploadRuns = 0

        let task = Task {
            await coordinator.run {
                uploadRuns += 1
                return await suspension.run()
            }
        }
        await suspension.waitUntilStarted()

        if coordinator.requestAttachmentMutation() {
            attachmentIDs.removeAll { $0 == second }
        }

        #expect(attachmentIDs == [first, second])
        #expect(uploadRuns == 1)
        suspension.resume(returning: ())
        _ = await task.value
        #expect(coordinator.requestAttachmentMutation())
    }

    @Test func attachInvalidInputNeverReturnsTheRawServerPath() {
        let rawPath = "input.media[0].privateInternalField"
        let message = ArticlePhotoAttachErrorMessage.localizedMessage(for: rawPath)

        #expect(message == ArticleInvalidInputMessage.localizedMessage(for: rawPath))
        #expect(!message.contains(rawPath))
        #expect(!message.contains("privateInternalField"))
    }
}

struct ArticleDraftLoadOutcomeTests {
    @Test func responseErrorsAndMissingDraftDoNotFallThroughToAnEmptyEditor() {
        #expect(ArticleDraftLoadOutcome.resolve(hasResponseErrors: true, hasDraft: true) == .failed)
        #expect(ArticleDraftLoadOutcome.resolve(hasResponseErrors: false, hasDraft: false) == .notFound)
        #expect(ArticleDraftLoadOutcome.resolve(hasResponseErrors: false, hasDraft: true) == .loaded)
    }
}

struct ArticleEditorOperationGateTests {
    @Test func busyOrFailedSaveCannotMakeAStaleDraftPublishable() {
        let idle = ArticleEditorOperationGate(hasValidTitle: true, isBusy: false)
        let busy = ArticleEditorOperationGate(hasValidTitle: true, isBusy: true)

        #expect(idle.canStartSaveDraft)
        #expect(idle.canStartPublish)
        #expect(!busy.canStartSaveDraft)
        #expect(!busy.canStartPublish)
    }
}

struct ArticleMediaDraftPreparationTests {
    @Test func blankTitlesAreBlockedWhileEmptyContentIsPreservedForMediaDrafts() {
        #expect(
            ArticleMediaDraftPreparation.prepare(title: "  \n", content: "Body") == .titleRequired
        )
        #expect(
            ArticleMediaDraftPreparation.prepare(title: "Actual title", content: "")
                == .ready(title: "Actual title", content: "")
        )
    }
}

struct ArticleInvalidInputMessageTests {
    @Test func mapsKnownFieldsAndKeepsUnknownServerPathsOutOfUserCopy() {
        #expect(ArticleInvalidInputMessage.localizationKey(for: "input.title") == "article.error.invalidTitle")
        #expect(ArticleInvalidInputMessage.localizationKey(for: "tags[0]") == "article.error.invalidTags")
        #expect(
            ArticleInvalidInputMessage.localizationKey(for: "private.internalField")
                == "article.error.invalidInput"
        )
    }
}
