@testable import HackersPub
import Testing

@MainActor
struct TimelineViewTaskOwnerTests {
    @Test func disappearanceCancelsSupervisorAndPaginationBeforeRemount() async {
        let owner = TimelineViewTaskOwner()
        let state = TaskOwnerFixture()

        let initialSupervisor = Task { @MainActor in
            await owner.supervise {
                state.initialSupervisorStarted += 1
                await state.waitForCancellation { state.initialSupervisorCancelled = true }
            }
        }
        await waitUntil { state.initialSupervisorStarted == 1 }

        owner.startRequest {
            state.newerRequestStarted += 1
            await state.waitForCancellation { state.newerRequestCancelled = true }
        }
        await waitUntil { state.newerRequestStarted == 1 }

        owner.cancelAll()
        await initialSupervisor.value
        await waitUntil {
            state.initialSupervisorCancelled && state.newerRequestCancelled
        }

        let remountedSupervisor = Task { @MainActor in
            await owner.supervise {
                state.remountedSupervisorStarted += 1
                await state.waitForCancellation { state.remountedSupervisorCancelled = true }
            }
        }
        await waitUntil { state.remountedSupervisorStarted == 1 }

        owner.startRequest {
            state.olderRequestStarted += 1
            await state.waitForCancellation { state.olderRequestCancelled = true }
        }
        await waitUntil { state.olderRequestStarted == 1 }

        owner.cancelAll()
        await remountedSupervisor.value
        await waitUntil {
            state.remountedSupervisorCancelled && state.olderRequestCancelled
        }

        #expect(state.initialSupervisorStarted == 1)
        #expect(state.newerRequestStarted == 1)
        #expect(state.remountedSupervisorStarted == 1)
        #expect(state.olderRequestStarted == 1)
    }

    @Test func staleCancelledRequestCannotReleaseTheRemountedPaginationSlot() async {
        let owner = TimelineViewTaskOwner()
        let state = TaskOwnerFixture()
        let staleGate = NonCancellingGate()

        owner.startRequest {
            state.staleRequestStarted += 1
            await staleGate.wait()
            state.staleRequestFinished += 1
        }
        await waitUntil { state.staleRequestStarted == 1 }

        owner.cancelAll()
        owner.startRequest {
            state.currentRequestStarted += 1
            await state.waitForCancellation { state.currentRequestCancelled = true }
        }
        await waitUntil { state.currentRequestStarted == 1 }

        staleGate.open()
        await waitUntil { state.staleRequestFinished == 1 }

        owner.startRequest {
            state.secondCurrentRequestStarted += 1
        }
        await settle()

        #expect(state.secondCurrentRequestStarted == 0)

        owner.cancelAll()
        await waitUntil { state.currentRequestCancelled }
    }

    private func waitUntil(
        _ condition: @MainActor () -> Bool,
        sourceLocation: SourceLocation = #_sourceLocation
    ) async {
        for _ in 0 ..< 100 where !condition() {
            await Task.yield()
        }
        #expect(condition(), sourceLocation: sourceLocation)
    }

    private func settle() async {
        for _ in 0 ..< 10 {
            await Task.yield()
        }
    }
}

@MainActor
private final class TaskOwnerFixture {
    var initialSupervisorStarted = 0
    var newerRequestStarted = 0
    var remountedSupervisorStarted = 0
    var olderRequestStarted = 0
    var initialSupervisorCancelled = false
    var newerRequestCancelled = false
    var remountedSupervisorCancelled = false
    var olderRequestCancelled = false
    var staleRequestStarted = 0
    var staleRequestFinished = 0
    var currentRequestStarted = 0
    var currentRequestCancelled = false
    var secondCurrentRequestStarted = 0

    func waitForCancellation(markCancelled: @escaping @MainActor () -> Void) async {
        do {
            try await Task.sleep(nanoseconds: 60_000_000_000)
        } catch is CancellationError {
            markCancelled()
        } catch {
            Issue.record("Unexpected task failure: \(error)")
        }
    }
}

@MainActor
private final class NonCancellingGate {
    private var continuation: CheckedContinuation<Void, Never>?

    func wait() async {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func open() {
        continuation?.resume()
        continuation = nil
    }
}
