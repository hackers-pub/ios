import Foundation

struct RefreshReplayState {
    struct Attempt: Equatable {
        let revision: Int
        let generation: Int
    }

    struct FinishResult {
        let hasPendingRefresh: Bool
        let hasNewerRevision: Bool
    }

    private var requestedRevision = 0
    private var completedRevision = 0
    private var nextAttemptGeneration = 0
    private var activeAttempt: Attempt?

    var hasPendingRefresh: Bool {
        requestedRevision > completedRevision
    }

    mutating func request() {
        requestedRevision += 1
    }

    mutating func beginIfNeeded(isBusy: Bool) -> Attempt? {
        guard !isBusy, activeAttempt == nil, hasPendingRefresh else { return nil }

        nextAttemptGeneration += 1
        let attempt = Attempt(
            revision: requestedRevision,
            generation: nextAttemptGeneration
        )
        activeAttempt = attempt
        return attempt
    }

    @discardableResult
    mutating func finish(_ attempt: Attempt, cancelled: Bool) -> Bool {
        let result = finishResult(attempt, cancelled: cancelled)
        return !cancelled && result.hasPendingRefresh
    }

    mutating func finishResult(_ attempt: Attempt, cancelled: Bool) -> FinishResult {
        guard activeAttempt == attempt else {
            return FinishResult(hasPendingRefresh: hasPendingRefresh, hasNewerRevision: false)
        }

        activeAttempt = nil
        if !cancelled {
            completedRevision = max(completedRevision, attempt.revision)
        }
        return FinishResult(
            hasPendingRefresh: hasPendingRefresh,
            hasNewerRevision: requestedRevision > attempt.revision
        )
    }

    mutating func cancelActiveAttempt() {
        activeAttempt = nil
    }
}

struct RefreshReplayOwner: Equatable, Sendable {
    fileprivate let generation: Int
    fileprivate let lease: RefreshReplayOwnerLease

    static func == (lhs: RefreshReplayOwner, rhs: RefreshReplayOwner) -> Bool {
        lhs.generation == rhs.generation && lhs.lease === rhs.lease
    }

    fileprivate var isValid: Bool {
        lease.isValid
    }

    fileprivate func invalidate() {
        lease.invalidate()
    }
}

enum RefreshReplayOperationResult: Equatable, Sendable {
    case completed
    case cancelled
    case deferred
}

@MainActor
final class RefreshReplayDriver {
    typealias InitialOperation = @MainActor (RefreshReplayOwner) async -> Void
    typealias IsBusy = @MainActor () -> Bool
    typealias Operation = @MainActor (RefreshReplayOwner) async -> RefreshReplayOperationResult

    private var replayState = RefreshReplayState()
    private var nextOwnerGeneration = 0
    private var activeOwner: RefreshReplayOwner?
    private var supervisorSignal: RefreshReplaySupervisorSignal?

    var hasPendingRefresh: Bool {
        replayState.hasPendingRefresh
    }

    var hasActiveSupervisor: Bool {
        activeOwner?.isValid == true && supervisorSignal != nil
    }

    var currentOwner: RefreshReplayOwner? {
        guard let activeOwner, activeOwner.isValid else { return nil }
        return activeOwner
    }

    func supervise(
        initialOperation: InitialOperation,
        isBusy: @escaping IsBusy,
        operation: @escaping Operation
    ) async {
        let (owner, signalStream) = activateSupervisor()

        await withTaskCancellationHandler {
            await initialOperation(owner)
            signal(owner)

            for await _ in signalStream {
                guard isActive(owner), !Task.isCancelled else { break }
                await runIfNeeded(owner: owner, isBusy: isBusy, operation: operation)
            }
        } onCancel: {
            owner.invalidate()
            Task { @MainActor in
                self.deactivateOwner(owner)
            }
        }

        deactivateOwner(owner)
    }

    func isActive(_ owner: RefreshReplayOwner) -> Bool {
        activeOwner == owner && owner.isValid
    }

    func withActiveOwner<Result>(
        _ owner: RefreshReplayOwner,
        perform operation: () -> Result
    ) -> Result? {
        guard activeOwner == owner else { return nil }
        return owner.lease.withValidity(perform: operation)
    }

    func request() {
        replayState.request()
        signalActiveOwner()
    }

    func notifyBusyReleased(owner: RefreshReplayOwner) {
        signal(owner)
    }

    private func activateSupervisor() -> (owner: RefreshReplayOwner, stream: AsyncStream<Void>) {
        if let activeOwner {
            deactivateOwner(activeOwner)
        }

        nextOwnerGeneration += 1
        let owner = RefreshReplayOwner(
            generation: nextOwnerGeneration,
            lease: RefreshReplayOwnerLease()
        )
        let signal = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        activeOwner = owner
        supervisorSignal = RefreshReplaySupervisorSignal(
            owner: owner,
            continuation: signal.continuation
        )
        signal.continuation.yield(())
        return (owner, signal.stream)
    }

    private func deactivateOwner(_ owner: RefreshReplayOwner) {
        owner.invalidate()
        guard activeOwner == owner else { return }

        activeOwner = nil
        replayState.cancelActiveAttempt()
        if supervisorSignal?.owner == owner {
            supervisorSignal?.continuation.finish()
            supervisorSignal = nil
        }
    }

    private func signalActiveOwner() {
        guard let activeOwner else { return }
        signal(activeOwner)
    }

    private func signal(_ owner: RefreshReplayOwner) {
        guard isActive(owner), supervisorSignal?.owner == owner else { return }
        supervisorSignal?.continuation.yield(())
    }

    private func runIfNeeded(
        owner: RefreshReplayOwner,
        isBusy: IsBusy,
        operation: Operation
    ) async {
        var usedCancellationHandoff = false

        while isActive(owner), !Task.isCancelled {
            guard let attempt = replayState.beginIfNeeded(isBusy: isBusy()) else { return }
            let operationResult = await operation(owner)
            let ownerCanContinue = isActive(owner) && !Task.isCancelled
            let effectiveResult = ownerCanContinue ? operationResult : .cancelled
            let finishResult = replayState.finishResult(
                attempt,
                cancelled: effectiveResult != .completed
            )

            guard ownerCanContinue else { return }

            switch effectiveResult {
            case .completed:
                guard finishResult.hasPendingRefresh else { return }
            case .cancelled:
                guard finishResult.hasNewerRevision, !usedCancellationHandoff else { return }
                usedCancellationHandoff = true
            case .deferred:
                return
            }
        }
    }
}

private struct RefreshReplaySupervisorSignal {
    let owner: RefreshReplayOwner
    let continuation: AsyncStream<Void>.Continuation
}

private final class RefreshReplayOwnerLease: @unchecked Sendable {
    private let lock = NSLock()
    private var valid = true

    var isValid: Bool {
        lock.withLock { valid }
    }

    func invalidate() {
        lock.withLock {
            valid = false
        }
    }

    func withValidity<Result>(perform operation: () -> Result) -> Result? {
        lock.withLock {
            guard valid else { return nil }
            return operation()
        }
    }
}
