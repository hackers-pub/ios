@testable import HackersPub
import Testing

@MainActor
struct RefreshReplayDriverTests {
    @Test(arguments: ProductionTimelineScope.allCases)
    func idleProductionSupervisorConsumesOneLaterNotification(
        scope: ProductionTimelineScope
    ) async {
        let driver = RefreshReplayDriver()
        var initialOperationCount = 0
        var refreshCount = 0
        let supervisor = Task { @MainActor in
            await driver.supervise(
                initialOperation: { _ in
                    initialOperationCount += 1
                },
                isBusy: { false },
                operation: { owner in
                    guard driver.isActive(owner) else { return .cancelled }
                    refreshCount += 1
                    return .completed
                }
            )
        }

        await waitUntil { driver.hasActiveSupervisor && initialOperationCount == 1 }
        await settle()
        #expect(driver.hasActiveSupervisor, "\(scope) supervisor returned after initial work")

        driver.request()
        await waitUntil { refreshCount == 1 }
        await settle()

        #expect(refreshCount == 1, "\(scope) should consume the notification exactly once")
        supervisor.cancel()
        await supervisor.value
    }

    @Test func disappearanceRejectsOldSignalsAndReappearanceConsumesPendingOnce() async throws {
        let driver = RefreshReplayDriver()
        var refreshCount = 0
        let firstSupervisor = supervisorTask(driver: driver) { owner in
            guard driver.isActive(owner) else { return .cancelled }
            refreshCount += 1
            return .completed
        }
        await waitUntil { driver.hasActiveSupervisor }
        let firstOwner = try #require(driver.currentOwner)

        firstSupervisor.cancel()
        await firstSupervisor.value
        #expect(!driver.hasActiveSupervisor)

        driver.request()
        driver.notifyBusyReleased(owner: firstOwner)
        await settle()
        #expect(refreshCount == 0)
        #expect(driver.hasPendingRefresh)

        let busyState = RefreshReplayBusyState()
        busyState.isBusy = true
        let secondSupervisor = supervisorTask(
            driver: driver,
            isBusy: { busyState.isBusy },
            operation: { owner in
                guard driver.isActive(owner) else { return .cancelled }
                refreshCount += 1
                return .completed
            }
        )
        await waitUntil { driver.hasActiveSupervisor }
        driver.notifyBusyReleased(owner: firstOwner)
        await settle()
        #expect(refreshCount == 0)

        let secondOwner = try #require(driver.currentOwner)
        busyState.isBusy = false
        driver.notifyBusyReleased(owner: secondOwner)
        await waitUntil { refreshCount == 1 }
        await settle()

        #expect(refreshCount == 1)
        #expect(!driver.hasPendingRefresh)
        secondSupervisor.cancel()
        await secondSupervisor.value
    }

    @Test func cancelledRefreshHandsANewerPendingRevisionToOneFollowUp() async {
        let driver = RefreshReplayDriver()
        var refreshCount = 0
        let supervisor = supervisorTask(driver: driver) { _ in
            refreshCount += 1
            if refreshCount == 1 {
                driver.request()
                return .cancelled
            }
            return .completed
        }
        await waitUntil { driver.hasActiveSupervisor }

        driver.request()
        await waitUntil { refreshCount == 2 }
        await settle()

        #expect(refreshCount == 2)
        #expect(!driver.hasPendingRefresh)
        supervisor.cancel()
        await supervisor.value
    }

    @Test(arguments: BusyTimelineOperation.allCases)
    func cancelledBusyProductionOperationHandsPendingRefreshToSupervisor(
        operationKind: BusyTimelineOperation
    ) async throws {
        let driver = RefreshReplayDriver()
        let initialGate = RefreshReplayCancellationGate()
        var isBusy = false
        var refreshCount = 0
        let supervisor = Task { @MainActor in
            await driver.supervise(
                initialOperation: { owner in
                    guard operationKind == .initial else { return }
                    isBusy = true
                    defer {
                        isBusy = false
                        driver.notifyBusyReleased(owner: owner)
                    }
                    driver.request()
                    try? await initialGate.wait()
                },
                isBusy: { isBusy },
                operation: { owner in
                    guard driver.isActive(owner) else { return .cancelled }
                    refreshCount += 1
                    return .completed
                }
            )
        }

        if operationKind == .initial {
            await waitUntil { isBusy && driver.hasPendingRefresh }
            initialGate.cancel()
        } else {
            await waitUntil { driver.hasActiveSupervisor }
            let owner = try #require(driver.currentOwner)
            let manualOperation = Task { @MainActor in
                isBusy = true
                defer {
                    isBusy = false
                    driver.notifyBusyReleased(owner: owner)
                }
                driver.request()
                _ = try? await Task.sleep(nanoseconds: 60_000_000_000)
            }
            await waitUntil { isBusy && driver.hasPendingRefresh }
            manualOperation.cancel()
            await manualOperation.value
        }

        await waitUntil { refreshCount == 1 }
        await settle()
        #expect(refreshCount == 1, "\(operationKind) should hand off exactly once")
        #expect(!driver.hasPendingRefresh)
        supervisor.cancel()
        await supervisor.value
    }

    @Test func repeatedSignalsCoalesceWithoutDuplicateRefreshOrBusySpin() async throws {
        let driver = RefreshReplayDriver()
        let busyState = RefreshReplayBusyState()
        var refreshCount = 0
        let supervisor = supervisorTask(
            driver: driver,
            isBusy: { busyState.isBusy },
            operation: { _ in
                refreshCount += 1
                return .completed
            }
        )
        await waitUntil { driver.hasActiveSupervisor }
        let owner = try #require(driver.currentOwner)

        busyState.isBusy = true
        for _ in 0 ..< 5 {
            driver.request()
            driver.notifyBusyReleased(owner: owner)
        }
        await settle()
        #expect(refreshCount == 0)

        busyState.isBusy = false
        for _ in 0 ..< 5 {
            driver.notifyBusyReleased(owner: owner)
        }
        await waitUntil { refreshCount == 1 }
        await settle()

        #expect(refreshCount == 1)
        #expect(!driver.hasPendingRefresh)
        supervisor.cancel()
        await supervisor.value
    }

    @Test func staleOwnerCompletionCannotWriteAfterANewSupervisorAppears() async {
        let driver = RefreshReplayDriver()
        let staleGate = RefreshReplayGate()
        let currentGate = RefreshReplayGate()
        var operationCount = 0
        var stateWriteCount = 0
        let operation: RefreshReplayDriver.Operation = { owner in
            operationCount += 1
            if operationCount == 1 {
                await staleGate.wait()
            } else {
                await currentGate.wait()
            }
            _ = driver.withActiveOwner(owner) {
                stateWriteCount += 1
            }
            return .completed
        }
        let staleSupervisor = supervisorTask(driver: driver, operation: operation)
        await waitUntil { driver.hasActiveSupervisor }
        driver.request()
        await waitUntil { operationCount == 1 }

        staleSupervisor.cancel()
        await waitUntil { !driver.hasActiveSupervisor }

        let currentSupervisor = supervisorTask(driver: driver, operation: operation)
        await waitUntil { operationCount == 2 }
        staleGate.open()
        await staleSupervisor.value
        await settle()

        #expect(stateWriteCount == 0)
        #expect(driver.hasPendingRefresh)

        currentGate.open()
        await waitUntil { stateWriteCount == 1 && !driver.hasPendingRefresh }

        #expect(operationCount == 2)
        #expect(stateWriteCount == 1)
        #expect(!driver.hasPendingRefresh)
        currentSupervisor.cancel()
        await currentSupervisor.value
    }

    private func supervisorTask(
        driver: RefreshReplayDriver,
        isBusy: @escaping RefreshReplayDriver.IsBusy = { false },
        operation: @escaping RefreshReplayDriver.Operation
    ) -> Task<Void, Never> {
        Task { @MainActor in
            await driver.supervise(
                initialOperation: { _ in },
                isBusy: isBusy,
                operation: operation
            )
        }
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

enum ProductionTimelineScope: String, CaseIterable, CustomStringConvertible, Sendable {
    case publicTimeline
    case personalTimeline
    case localTimeline
    case exploreLocal
    case exploreGlobal

    var description: String {
        rawValue
    }
}

enum BusyTimelineOperation: String, CaseIterable, CustomStringConvertible, Sendable {
    case initial
    case pullToRefresh
    case loadMore
    case loadNewer

    var description: String {
        rawValue
    }
}

@MainActor
private final class RefreshReplayGate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var isOpen = false

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func open() {
        isOpen = true
        continuation?.resume()
        continuation = nil
    }
}

@MainActor
private final class RefreshReplayCancellationGate {
    private var continuation: CheckedContinuation<Void, Error>?

    func wait() async throws {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    func cancel() {
        continuation?.resume(throwing: CancellationError())
        continuation = nil
    }
}

@MainActor
private final class RefreshReplayBusyState {
    var isBusy = false
}
