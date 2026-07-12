import Foundation
@testable import HackersPub
import Testing

@MainActor
struct ComposeSubmissionCoordinatorTests {
    @Test func doubleSubmitStartsOnlyOneUploadAndOneMutation() async throws {
        let coordinator = ComposeSubmissionCoordinator()
        let blocker = ControlledAsyncOperation()
        var prepareCalls = 0
        var uploadCalls = 0
        var mutationCalls = 0

        let first = try #require(coordinator.prepareSubmission {
            prepareCalls += 1
            return "prepared-request"
        })
        let duplicate = try coordinator.prepareSubmission {
            prepareCalls += 1
            return "duplicate-request"
        }

        #expect(duplicate == nil)
        #expect(prepareCalls == 1)

        let firstTask = Task {
            try await coordinator.perform(
                first,
                upload: { request in
                    uploadCalls += 1
                    await blocker.run()
                    return "uploaded-\(request)"
                },
                submit: { _, uploaded in
                    mutationCalls += 1
                    return uploaded
                }
            )
        }

        await blocker.waitUntilStarted()
        #expect(coordinator.isSubmitting)
        #expect(uploadCalls == 1)
        #expect(mutationCalls == 0)

        blocker.finish()
        let outcome = try await firstTask.value

        guard case let .completed(value) = outcome else {
            Issue.record("The accepted submission did not complete")
            return
        }
        #expect(value == "uploaded-prepared-request")
        #expect(uploadCalls == 1)
        #expect(mutationCalls == 1)
        #expect(!coordinator.isSubmitting)
    }

    @Test func cancellationReleasesTheSubmissionPermit() async throws {
        let coordinator = ComposeSubmissionCoordinator()
        let uploadStarted = AsyncStartSignal()
        let prepared = try #require(coordinator.prepareSubmission { "request" })

        let task = Task {
            try await coordinator.perform(
                prepared,
                upload: { _ in
                    uploadStarted.signal()
                    try await Task.sleep(nanoseconds: 60_000_000_000)
                    return "never"
                },
                submit: { _, uploaded in uploaded }
            )
        }

        await uploadStarted.wait()
        task.cancel()

        do {
            _ = try await task.value
            Issue.record("Cancellation should leave through the throwing path")
        } catch is CancellationError {
            // Expected.
        }

        #expect(!coordinator.isSubmitting)
        #expect(try coordinator.prepareSubmission { "retry" } != nil)
    }

    @Test func photoSelectionsUseRemainingCapacityAcrossRounds() throws {
        let coordinator = ComposeSubmissionCoordinator()
        let firstItems = Array(0 ..< 7)
        let firstAttachmentIDs = Set<UUID>()

        let firstSelection = try #require(
            coordinator.preparePhotoSelection(
                items: firstItems,
                currentAttachmentIDs: firstAttachmentIDs,
                maximumAttachmentCount: 10
            )
        )

        #expect(firstSelection.items == firstItems)
        #expect(firstSelection.omittedForLimitCount == 0)
        #expect(firstSelection.token.capacity == 10)
        #expect(firstSelection.token.attachmentIDs == firstAttachmentIDs)
        coordinator.finishPhotoLoading(firstSelection.token)

        let sevenAttachmentIDs = Set((0 ..< 7).map { _ in UUID() })
        let secondItems = Array(7 ..< 14)
        let secondSelection = try #require(
            coordinator.preparePhotoSelection(
                items: secondItems,
                currentAttachmentIDs: sevenAttachmentIDs,
                maximumAttachmentCount: 10
            )
        )

        #expect(secondSelection.items == Array(secondItems.prefix(3)))
        #expect(secondSelection.omittedForLimitCount == 4)
        #expect(secondSelection.token.capacity == 3)
        #expect(secondSelection.token.attachmentIDs == sevenAttachmentIDs)
        coordinator.finishPhotoLoading(secondSelection.token)
    }

    @Test func fullPhotoSelectionSkipsLoadingAndRemovalReopensSlots() throws {
        let coordinator = ComposeSubmissionCoordinator()
        let tenAttachmentIDs = Set((0 ..< 10).map { _ in UUID() })
        var loaderCallCount = 0

        let rejectedSelection = coordinator.preparePhotoSelection(
            items: [1, 2, 3],
            currentAttachmentIDs: tenAttachmentIDs,
            maximumAttachmentCount: 10
        )
        if let rejectedSelection {
            loaderCallCount += rejectedSelection.items.count
        }

        #expect(rejectedSelection == nil)
        #expect(loaderCallCount == 0)
        #expect(
            coordinator.remainingPhotoCapacity(
                currentAttachmentIDs: tenAttachmentIDs,
                maximumAttachmentCount: 10
            ) == 0
        )

        let afterRemovalIDs = Set(tenAttachmentIDs.dropFirst(2))
        let reopenedSelection = try #require(
            coordinator.preparePhotoSelection(
                items: [1, 2, 3],
                currentAttachmentIDs: afterRemovalIDs,
                maximumAttachmentCount: 10
            )
        )

        #expect(reopenedSelection.items == [1, 2])
        #expect(reopenedSelection.omittedForLimitCount == 1)
        #expect(reopenedSelection.token.capacity == 2)
        coordinator.finishPhotoLoading(reopenedSelection.token)
    }

    @Test func loadedPhotosCannotExceedCapacityOrApplyFromStaleState() throws {
        let coordinator = ComposeSubmissionCoordinator()
        let originalAttachmentIDs = Set((0 ..< 8).map { _ in UUID() })
        let firstSelection = try #require(
            coordinator.preparePhotoSelection(
                items: [1, 2, 3, 4],
                currentAttachmentIDs: originalAttachmentIDs,
                maximumAttachmentCount: 10
            )
        )

        let accepted = try #require(
            coordinator.loadedPhotosToAppend(
                ["first", "second", "unexpected-third"],
                for: firstSelection.token,
                currentAttachmentIDs: originalAttachmentIDs
            )
        )
        #expect(accepted == ["first", "second"])
        #expect(originalAttachmentIDs.count + accepted.count == 10)
        coordinator.finishPhotoLoading(firstSelection.token)

        let newerAttachmentIDs = Set((0 ..< 9).map { _ in UUID() })
        let secondSelection = try #require(
            coordinator.preparePhotoSelection(
                items: [5],
                currentAttachmentIDs: newerAttachmentIDs,
                maximumAttachmentCount: 10
            )
        )

        #expect(
            coordinator.loadedPhotosToAppend(
                ["stale"],
                for: firstSelection.token,
                currentAttachmentIDs: originalAttachmentIDs
            ) == nil
        )
        #expect(coordinator.isLoadingPhotos)

        let afterRemovalIDs = Set(newerAttachmentIDs.dropFirst())
        #expect(
            coordinator.loadedPhotosToAppend(
                ["removed-state"],
                for: secondSelection.token,
                currentAttachmentIDs: afterRemovalIDs
            ) == nil
        )
        coordinator.finishPhotoLoading(firstSelection.token)
        #expect(coordinator.isLoadingPhotos)
        coordinator.finishPhotoLoading(secondSelection.token)
        #expect(!coordinator.isLoadingPhotos)
    }

    @Test func pendingPhotoLoadRejectsSubmitAndStaleCompletionCannotClearBusy() async throws {
        let coordinator = ComposeSubmissionCoordinator()
        let blocker = ControlledAsyncOperation()
        let firstSelection = try #require(
            coordinator.preparePhotoSelection(
                items: [1],
                currentAttachmentIDs: [],
                maximumAttachmentCount: 10
            )
        )

        let loadTask = Task {
            await blocker.run()
            coordinator.finishPhotoLoading(firstSelection.token)
        }
        await blocker.waitUntilStarted()

        var prepareCalls = 0
        let rejected = try coordinator.prepareSubmission {
            prepareCalls += 1
            return "request"
        }
        #expect(rejected == nil)
        #expect(prepareCalls == 0)
        #expect(coordinator.isLoadingPhotos)

        blocker.finish()
        await loadTask.value
        #expect(!coordinator.isLoadingPhotos)

        let secondSelection = try #require(
            coordinator.preparePhotoSelection(
                items: [2],
                currentAttachmentIDs: [],
                maximumAttachmentCount: 10
            )
        )
        coordinator.finishPhotoLoading(firstSelection.token)
        #expect(coordinator.isLoadingPhotos)
        coordinator.finishPhotoLoading(secondSelection.token)
        #expect(!coordinator.isLoadingPhotos)
    }

    @Test func invalidInputFromInjectedMutationNeverExposesItsRawPath() async throws {
        let coordinator = ComposeSubmissionCoordinator()
        let rawPath = "input.internal.futureField"
        let prepared = try #require(coordinator.prepareSubmission { "request" })
        let outcome = try await coordinator.perform(
            prepared,
            upload: { _ in [String]() },
            submit: { _, _ in
                ComposeNoteSubmissionResult.invalidInput(inputPath: rawPath)
            }
        )

        guard case let .completed(result) = outcome else {
            Issue.record("The injected mutation result was not delivered")
            return
        }

        var presentation = ComposePresentationCoordinator()
        let action = presentation.handleSubmissionResult(result)
        let message = try #require(presentation.errorMessage)

        #expect(action == .none)
        #expect(!message.contains(rawPath))
        #expect(!message.localizedCaseInsensitiveContains("futureField"))
        #expect(!message.localizedCaseInsensitiveContains("input.internal"))
    }
}

@MainActor
private final class ControlledAsyncOperation {
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var completion: CheckedContinuation<Void, Never>?
    private(set) var isStarted = false

    func run() async {
        isStarted = true
        startWaiters.forEach { $0.resume() }
        startWaiters.removeAll()
        await withCheckedContinuation { continuation in
            completion = continuation
        }
    }

    func waitUntilStarted() async {
        guard !isStarted else { return }
        await withCheckedContinuation { continuation in
            startWaiters.append(continuation)
        }
    }

    func finish() {
        completion?.resume()
        completion = nil
    }
}

@MainActor
private final class AsyncStartSignal {
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var hasStarted = false

    func signal() {
        hasStarted = true
        waiters.forEach { $0.resume() }
        waiters.removeAll()
    }

    func wait() async {
        guard !hasStarted else { return }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }
}
