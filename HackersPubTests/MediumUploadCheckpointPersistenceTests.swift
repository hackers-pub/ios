import Foundation
@testable import HackersPub
import Testing

@Suite(.serialized)
struct MediumUploadCheckpointPersistenceTests {
    @Test
    func transientFinishSurvivesServiceAndStoreReloadWithoutAnotherStartOrPUT() async throws {
        let fixture = MediumUploadCheckpointFixture(
            finishSteps: [.transientFailure, .transientFailure, .transientFailure, .success]
        )
        let data = try checkpointTestImageData()
        let scopeIdentifier = "session-a"

        do {
            _ = try await fixture.makeService(
                scopeProvider: FixedMediumUploadScopeProvider(scopeIdentifier)
            ).uploadImageData(data)
            Issue.record("Expected bounded transient finish retries to fail")
        } catch {
            #expect(error is URLError)
        }

        let key = try fixture.checkpointKey(data: data, scopeIdentifier: scopeIdentifier)
        let reloadedCheckpoint = try await fixture.makeStore().loadCheckpoint(for: key)
        #expect(reloadedCheckpoint?.state == .finishPending)

        let medium = try await fixture.makeService(
            scopeProvider: FixedMediumUploadScopeProvider(scopeIdentifier)
        ).uploadImageData(data)

        #expect(medium.id == "medium-upload-1")
        #expect(fixture.transport.snapshot().startRequests == 1)
        #expect(await fixture.controller.snapshotRequestCount() == 1)
        #expect(fixture.transport.snapshot().finishUploadIDs == Array(repeating: "upload-1", count: 4))
        #expect(try await fixture.makeStore().loadCheckpoint(for: key) == nil)
    }

    @Test
    func finishCancellationSurvivesStoreReloadAsFinishOnlyRetry() async throws {
        let fixture = MediumUploadCheckpointFixture(finishSteps: [.cancellation, .success])
        let data = try checkpointTestImageData()
        let scopeIdentifier = "session-a"

        do {
            _ = try await fixture.makeService(
                scopeProvider: FixedMediumUploadScopeProvider(scopeIdentifier)
            ).uploadImageData(data)
            Issue.record("Expected finish cancellation")
        } catch is CancellationError {
            // Expected: the durable checkpoint must remain resumable.
        }

        let key = try fixture.checkpointKey(data: data, scopeIdentifier: scopeIdentifier)
        #expect(try await fixture.makeStore().loadCheckpoint(for: key)?.state == .finishPending)

        _ = try await fixture.makeService(
            scopeProvider: FixedMediumUploadScopeProvider(scopeIdentifier)
        ).uploadImageData(data)

        #expect(fixture.transport.snapshot().startRequests == 1)
        #expect(await fixture.controller.snapshotRequestCount() == 1)
        #expect(fixture.transport.snapshot().finishUploadIDs == ["upload-1", "upload-1"])
    }

    @Test
    func cancellationBeforePUTResponseReloadsUploadingCheckpointAndReusesTarget() async throws {
        try await verifyPUTCancellationRecovery(behavior: .suspendBeforeResponse)
    }

    @Test
    func cancellationAfterPUTResponseHeadersReloadsUploadingCheckpointAndReusesTarget() async throws {
        try await verifyPUTCancellationRecovery(behavior: .suspendAfterResponseHeaders)
    }

    @Test
    func finishSuccessClearsDurableCheckpoint() async throws {
        let fixture = MediumUploadCheckpointFixture(finishSteps: [.success, .success])
        let data = try checkpointTestImageData()
        let scopeIdentifier = "session-a"
        let provider = FixedMediumUploadScopeProvider(scopeIdentifier)
        let key = try fixture.checkpointKey(data: data, scopeIdentifier: scopeIdentifier)

        _ = try await fixture.makeService(scopeProvider: provider).uploadImageData(data)
        #expect(try await fixture.makeStore().loadCheckpoint(for: key) == nil)

        _ = try await fixture.makeService(scopeProvider: provider).uploadImageData(data)
        #expect(fixture.transport.snapshot().startRequests == 2)
        #expect(await fixture.controller.snapshotRequestCount() == 2)
        #expect(fixture.transport.snapshot().finishUploadIDs == ["upload-1", "upload-2"])
    }

    @Test
    func terminalInvalidInputClearsDurableCheckpoint() async throws {
        let fixture = MediumUploadCheckpointFixture(finishSteps: [.invalidInput, .success])
        let data = try checkpointTestImageData()
        let scopeIdentifier = "session-a"
        let provider = FixedMediumUploadScopeProvider(scopeIdentifier)
        let key = try fixture.checkpointKey(data: data, scopeIdentifier: scopeIdentifier)

        do {
            _ = try await fixture.makeService(scopeProvider: provider).uploadImageData(data)
            Issue.record("Expected terminal invalid input")
        } catch let error as MediumUploadError {
            guard case .invalidInput("uploadId") = error else {
                Issue.record("Expected invalid uploadId, received \(error)")
                return
            }
        }
        #expect(try await fixture.makeStore().loadCheckpoint(for: key) == nil)

        _ = try await fixture.makeService(scopeProvider: provider).uploadImageData(data)
        #expect(fixture.transport.snapshot().startRequests == 2)
        #expect(await fixture.controller.snapshotRequestCount() == 2)
    }

    private func verifyPUTCancellationRecovery(
        behavior: CheckpointUploadRequestController.Behavior
    ) async throws {
        let fixture = MediumUploadCheckpointFixture(
            finishSteps: [.success],
            uploadBehavior: behavior
        )
        let data = try checkpointTestImageData()
        let scopeIdentifier = "session-a"
        let provider = FixedMediumUploadScopeProvider(scopeIdentifier)
        let service = fixture.makeService(scopeProvider: provider)
        let task = Task {
            try await service.uploadImageData(data)
        }

        await fixture.controller.waitForRequestCount(1)
        task.cancel()
        await fixture.controller.setBehavior(.succeed)
        await fixture.controller.releaseAll()

        do {
            _ = try await task.value
            Issue.record("Expected the owner upload to observe cancellation")
        } catch is CancellationError {
            // Expected.
        } catch let error as URLError {
            #expect(error.code == .cancelled)
        }

        let key = try fixture.checkpointKey(data: data, scopeIdentifier: scopeIdentifier)
        #expect(try await fixture.makeStore().loadCheckpoint(for: key)?.state == .uploading)

        _ = try await fixture.makeService(scopeProvider: provider).uploadImageData(data)

        #expect(fixture.transport.snapshot().startRequests == 1)
        #expect(await fixture.controller.snapshotRequestCount() == 2)
        #expect(fixture.transport.snapshot().finishUploadIDs == ["upload-1"])
        #expect(try await fixture.makeStore().loadCheckpoint(for: key) == nil)
    }
}
