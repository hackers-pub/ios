import Foundation
@testable import HackersPub
import Testing

private enum WaiterOutcome: Equatable, Sendable {
    case success(String)
    case cancelled
    case failure(String)
}

private actor WaiterOutcomeProbe {
    private var outcomes: [WaiterOutcome] = []

    func record(_ outcome: WaiterOutcome) {
        outcomes.append(outcome)
    }

    func snapshot() -> [WaiterOutcome] {
        outcomes
    }
}

private actor SuspendedSecondRequestScopeProvider: MediumUploadScopeProviding {
    private let scope: MediumUploadCheckpointScope
    private var requestCount = 0
    private var countWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseWaiters: [CheckedContinuation<Void, Never>] = []

    init(_ identifier: String) {
        scope = MediumUploadCheckpointScope(accountOrSessionIdentifier: identifier)
    }

    func currentScope() async throws -> MediumUploadCheckpointScope {
        requestCount += 1
        if requestCount >= 2 {
            let waiters = countWaiters
            countWaiters.removeAll()
            waiters.forEach { $0.resume() }
        }
        if requestCount == 2 {
            await withCheckedContinuation { continuation in
                releaseWaiters.append(continuation)
            }
        }
        return scope
    }

    func waitForSecondRequest() async {
        guard requestCount < 2 else { return }
        await withCheckedContinuation { continuation in
            countWaiters.append(continuation)
        }
    }

    func releaseSecondRequest() {
        let waiters = releaseWaiters
        releaseWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }
}

@Suite(.serialized)
struct MediumUploadWaiterCancellationTests {
    @Test
    func cancelledRegisteredWaiterReturnsPromptlyWhileOwnerRemainsSuspended() async throws {
        let fixture = MediumUploadCheckpointFixture(
            finishSteps: [.success],
            uploadBehavior: .suspendBeforeResponse
        )
        let data = try checkpointTestImageData()
        let provider = ObservedMediumUploadScopeProvider("session-a")
        let service = fixture.makeService(scopeProvider: provider)
        let key = try fixture.checkpointKey(data: data, scopeIdentifier: "session-a")
        let owner = Task { try await service.uploadImageData(data) }
        await fixture.controller.waitForRequestCount(1)

        let probe = WaiterOutcomeProbe()
        let waiter = waiterTask(service: service, data: data, probe: probe)
        await provider.waitForRequestCount(2)
        try await waitForWaiterCount(1, service: service, key: key)

        waiter.cancel()
        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(await probe.snapshot() == [.cancelled])
        #expect(await service.inFlightWaiterCount(for: key) == 0)
        #expect(await fixture.controller.snapshotRequestCount() == 1)

        await fixture.controller.setBehavior(.succeed)
        await fixture.controller.releaseAll()
        #expect(try await owner.value.id == "medium-upload-1")
        #expect(await waiter.value == .cancelled)
        #expect(fixture.transport.snapshot().startRequests == 1)
        #expect(await fixture.controller.snapshotRequestCount() == 1)
        #expect(fixture.transport.snapshot().finishUploadIDs == ["upload-1"])
    }

    @Test
    func cancellationBeforeRegistrationNeverLeaksAWaiter() async throws {
        let fixture = MediumUploadCheckpointFixture(
            finishSteps: [.success],
            uploadBehavior: .suspendBeforeResponse
        )
        let data = try checkpointTestImageData()
        let provider = SuspendedSecondRequestScopeProvider("session-a")
        let service = fixture.makeService(scopeProvider: provider)
        let key = try fixture.checkpointKey(data: data, scopeIdentifier: "session-a")
        let owner = Task { try await service.uploadImageData(data) }
        await fixture.controller.waitForRequestCount(1)

        let probe = WaiterOutcomeProbe()
        let waiter = waiterTask(service: service, data: data, probe: probe)
        await provider.waitForSecondRequest()
        #expect(await service.inFlightWaiterCount(for: key) == 0)

        waiter.cancel()
        await provider.releaseSecondRequest()
        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(await probe.snapshot() == [.cancelled])
        #expect(await service.inFlightWaiterCount(for: key) == 0)

        await fixture.controller.setBehavior(.succeed)
        await fixture.controller.releaseAll()
        _ = try await owner.value
        #expect(await waiter.value == .cancelled)
        #expect(await fixture.controller.snapshotRequestCount() == 1)
    }

    @Test
    func registrationCompletionAndCancellationRaceResumesEveryWaiterExactlyOnce() async throws {
        let fixture = MediumUploadCheckpointFixture(
            finishSteps: [.success],
            uploadBehavior: .suspendBeforeResponse
        )
        let data = try checkpointTestImageData()
        let provider = ObservedMediumUploadScopeProvider("session-a")
        let service = fixture.makeService(scopeProvider: provider)
        let key = try fixture.checkpointKey(data: data, scopeIdentifier: "session-a")
        let owner = Task { try await service.uploadImageData(data) }
        await fixture.controller.waitForRequestCount(1)

        let probe = WaiterOutcomeProbe()
        let waiters = (0 ..< 12).map { _ in
            waiterTask(service: service, data: data, probe: probe)
        }
        await provider.waitForRequestCount(13)
        try await waitForWaiterCount(12, service: service, key: key)

        let release = Task { await fixture.controller.releaseAll() }
        waiters.prefix(6).forEach { $0.cancel() }
        await release.value

        _ = try await owner.value
        let outcomes = await waiters.asyncMap { await $0.value }

        #expect(outcomes.count == 12)
        #expect(!outcomes.contains { outcome in
            if case .failure = outcome {
                return true
            }
            return false
        })
        #expect(outcomes.suffix(6).allSatisfy {
            if case .success = $0 {
                return true
            }
            return false
        })
        #expect(await probe.snapshot().count == 12)
        #expect(await service.inFlightWaiterCount(for: key) == 0)
        #expect(fixture.transport.snapshot().startRequests == 1)
        #expect(await fixture.controller.snapshotRequestCount() == 1)
        #expect(fixture.transport.snapshot().finishUploadIDs == ["upload-1"])
    }

    private func waiterTask(
        service: MediumUploadService,
        data: Data,
        probe: WaiterOutcomeProbe
    ) -> Task<WaiterOutcome, Never> {
        Task {
            let outcome: WaiterOutcome
            do {
                outcome = try await .success(service.uploadImageData(data).id)
            } catch is CancellationError {
                outcome = .cancelled
            } catch {
                outcome = .failure(String(describing: error))
            }
            await probe.record(outcome)
            return outcome
        }
    }

    private func waitForWaiterCount(
        _ expected: Int,
        service: MediumUploadService,
        key: MediumUploadCheckpointKey
    ) async throws {
        for _ in 0 ..< 100 {
            if await service.inFlightWaiterCount(for: key) == expected {
                return
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        Issue.record("Timed out waiting for \(expected) registered upload waiters")
    }
}

private extension Array {
    func asyncMap<T>(_ transform: (Element) async -> T) async -> [T] {
        var results: [T] = []
        results.reserveCapacity(count)
        for element in self {
            await results.append(transform(element))
        }
        return results
    }
}
