import Foundation
@testable import HackersPub
import Testing

struct ProfileUpdateResponseGateTests {
    @Test func onlyACompleteResponseWithoutGraphQLErrorsCanDismissTheEditor() {
        #expect(ProfileUpdateResponseGate.shouldDismiss(hasResponseErrors: false, hasAccount: true))
        #expect(!ProfileUpdateResponseGate.shouldDismiss(hasResponseErrors: true, hasAccount: true))
        #expect(!ProfileUpdateResponseGate.shouldDismiss(hasResponseErrors: false, hasAccount: false))
    }
}

struct ProfileEditSnapshotTests {
    @Test func editsToDetailsLinksOrAvatarIntentAreUnsavedChanges() {
        let link = EditableProfileLink(name: "Website", url: "https://example.com")
        let initial = ProfileEditSnapshot(
            name: "Alice",
            bio: "Hello",
            links: [link],
            avatarIntent: .unchanged
        )

        #expect(initial == initial)
        #expect(initial != ProfileEditSnapshot(name: "Alicia", bio: "Hello", links: [link], avatarIntent: .unchanged))
        #expect(initial != ProfileEditSnapshot(name: "Alice", bio: "Updated", links: [link], avatarIntent: .unchanged))
        #expect(initial != ProfileEditSnapshot(name: "Alice", bio: "Hello", links: [], avatarIntent: .unchanged))
        #expect(initial != ProfileEditSnapshot(
            name: "Alice",
            bio: "Hello",
            links: [link],
            avatarIntent: .replacement(Data([0x01]))
        ))
    }
}

@MainActor
struct ProfileSaveCoordinatorTests {
    @Test func twoRapidSavesStartOnlyOneMutation() async {
        let coordinator = ProfileSaveCoordinator()
        let operation = ControlledProfileOperation<ProfileSaveMutationResponse>()
        let snapshot = profileSnapshot(name: "Alice")
        let currentSnapshot = snapshot
        var mutationCalls = 0

        let firstTask = Task {
            await coordinator.save(
                snapshot: snapshot,
                currentSnapshot: { currentSnapshot },
                operation: {
                    mutationCalls += 1
                    return await operation.run()
                }
            )
        }
        await operation.waitUntilStarted()

        let secondResult = await coordinator.save(
            snapshot: snapshot,
            currentSnapshot: { currentSnapshot },
            operation: {
                mutationCalls += 1
                return .saved
            }
        )

        #expect(mutationCalls == 1)
        guard case .blocked = secondResult else {
            Issue.record("Expected the second save to be blocked")
            return
        }

        operation.resume(returning: .saved)
        let firstResult = await firstTask.value
        guard case .current(.saved) = firstResult else {
            Issue.record("Expected the first save to finish as current")
            return
        }
    }

    @Test func revisionChangeMakesACompletedSaveStaleAndPreventsDismissal() async {
        let coordinator = ProfileSaveCoordinator()
        let operation = ControlledProfileOperation<ProfileSaveMutationResponse>()
        let submittedSnapshot = profileSnapshot(name: "Alice")
        var currentSnapshot = submittedSnapshot
        var dismissed = false

        let task = Task {
            await coordinator.save(
                snapshot: submittedSnapshot,
                currentSnapshot: { currentSnapshot },
                operation: {
                    await operation.run()
                }
            )
        }
        await operation.waitUntilStarted()
        currentSnapshot = profileSnapshot(name: "Alicia")
        operation.resume(returning: .saved)

        let result = await task.value
        if case .current(.saved) = result {
            dismissed = true
        }

        guard case .stale(.saved) = result else {
            Issue.record("Expected the completed save to be stale")
            return
        }
        #expect(!dismissed)
    }

    private func profileSnapshot(name: String) -> ProfileEditSnapshot {
        ProfileEditSnapshot(name: name, bio: "Hello", links: [], avatarIntent: .unchanged)
    }
}

@MainActor
struct ProfilePhotoLoadCoordinatorTests {
    @Test func newerItemWinsWhenAnOlderFailureCompletesLast() async {
        let coordinator = ProfilePhotoLoadCoordinator()
        let oldRequest = ControlledProfileOperation<ProfilePhotoLoadAttempt>()
        let newRequest = ControlledProfileOperation<ProfilePhotoLoadAttempt>()
        let newData = Data([0x02])

        let oldTask = Task {
            await coordinator.load(itemID: "old-item") {
                await oldRequest.run()
            }
        }
        await oldRequest.waitUntilStarted()

        let newTask = Task {
            await coordinator.load(itemID: "new-item") {
                await newRequest.run()
            }
        }
        await newRequest.waitUntilStarted()

        newRequest.resume(returning: .loaded(newData))
        let newResult = await newTask.value
        oldRequest.resume(returning: .failed("old failure"))
        let oldResult = await oldTask.value

        guard case let .current(_, .loaded(selectedData)) = newResult else {
            Issue.record("Expected the newer item to be current")
            return
        }
        #expect(selectedData == newData)
        var appliedData: Data?
        #expect(coordinator.applyIfCurrent(newResult) { attempt in
            if case let .loaded(data) = attempt {
                appliedData = data
            }
        })
        #expect(appliedData == newData)
        guard case .stale = oldResult else {
            Issue.record("Expected the older failure to be ignored")
            return
        }
        #expect(!coordinator.applyIfCurrent(oldResult) { _ in
            Issue.record("A stale failure must not be applied")
        })
    }

    @Test func completedItemCannotApplyAfterANewerItemStarts() async {
        let coordinator = ProfilePhotoLoadCoordinator()
        let firstRequest = ControlledProfileOperation<ProfilePhotoLoadAttempt>()
        let secondRequest = ControlledProfileOperation<ProfilePhotoLoadAttempt>()

        let firstTask = Task {
            await coordinator.load(itemID: "first-item") {
                await firstRequest.run()
            }
        }
        await firstRequest.waitUntilStarted()
        firstRequest.resume(returning: .loaded(Data([0x01])))
        let firstResult = await firstTask.value

        let secondTask = Task {
            await coordinator.load(itemID: "second-item") {
                await secondRequest.run()
            }
        }
        await secondRequest.waitUntilStarted()

        #expect(!coordinator.applyIfCurrent(firstResult) { _ in
            Issue.record("An older completed item must not overwrite a newer selection")
        })

        secondRequest.resume(returning: .loaded(Data([0x02])))
        _ = await secondTask.value
    }

    @Test func invalidatingASelectionMakesItsPendingLoadStale() async {
        let coordinator = ProfilePhotoLoadCoordinator()
        let request = ControlledProfileOperation<ProfilePhotoLoadAttempt>()

        let task = Task {
            await coordinator.load(itemID: "removed-item") {
                await request.run()
            }
        }
        await request.waitUntilStarted()
        coordinator.invalidate()
        request.resume(returning: .loaded(Data([0x01])))

        guard case .stale = await task.value else {
            Issue.record("Expected an invalidated photo load to be stale")
            return
        }
    }
}

@MainActor
private final class ControlledProfileOperation<Value> {
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

struct ProfileEditCloseRouteTests {
    @Test func closeRequestsBlockBusyEditorsAndConfirmDirtyEditors() {
        #expect(ProfileEditCloseRoute.resolve(hasChanges: false, isBusy: false) == .dismiss)
        #expect(ProfileEditCloseRoute.resolve(hasChanges: true, isBusy: false) == .confirmDiscard)
        #expect(ProfileEditCloseRoute.resolve(hasChanges: true, isBusy: true) == .blocked)
    }
}

struct ProfileAvatarIntentTests {
    @Test func unchangedReplacementAndRemovalProduceDistinctMutationPlans() {
        let data = Data([0x01])

        #expect(ProfileAvatarIntent.unchanged.mutationPlan == .omit)
        #expect(ProfileAvatarIntent.replacement(data).mutationPlan == .upload(data))
        #expect(ProfileAvatarIntent.remove.mutationPlan == .clear)
        #expect(!ProfileAvatarIntent.unchanged.requiresUpload)
        #expect(ProfileAvatarIntent.replacement(data).requiresUpload)
        #expect(!ProfileAvatarIntent.remove.requiresUpload)
    }

    @Test func restoringAnAvatarReturnsToTheUnchangedIntent() {
        var intent: ProfileAvatarIntent = .remove

        intent.restore()

        #expect(intent == .unchanged)
    }
}
