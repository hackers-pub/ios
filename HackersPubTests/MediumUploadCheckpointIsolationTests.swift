import Foundation
@testable import HackersPub
import Testing

@Suite(.serialized)
struct MediumUploadCheckpointIsolationTests {
    @Test
    func concurrentIdenticalUploadsSingleFlightAndCancelledWaiterDoesNotCancelOwner() async throws {
        let fixture = MediumUploadCheckpointFixture(
            finishSteps: [.success],
            uploadBehavior: .suspendBeforeResponse
        )
        let data = try checkpointTestImageData()
        let provider = ObservedMediumUploadScopeProvider("session-a")
        let service = fixture.makeService(scopeProvider: provider)

        let owner = Task {
            try await service.uploadImageData(data)
        }
        await fixture.controller.waitForRequestCount(1)

        let waiter = Task {
            try await service.uploadImageData(data)
        }
        await provider.waitForRequestCount(2)
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(await fixture.controller.snapshotRequestCount() == 1)
        waiter.cancel()

        await fixture.controller.setBehavior(.succeed)
        await fixture.controller.releaseAll()

        let medium = try await owner.value
        #expect(medium.id == "medium-upload-1")
        do {
            _ = try await waiter.value
            Issue.record("Expected the cancelled waiter to observe cancellation")
        } catch is CancellationError {
            // Expected; cancellation must not propagate into the owner operation.
        }

        #expect(fixture.transport.snapshot().startRequests == 1)
        #expect(await fixture.controller.snapshotRequestCount() == 1)
        #expect(fixture.transport.snapshot().finishUploadIDs == ["upload-1"])
    }

    @Test
    func differentSessionScopeDoesNotReuseCheckpoint() async throws {
        let fixture = MediumUploadCheckpointFixture(
            finishSteps: [.transientFailure, .transientFailure, .transientFailure, .success]
        )
        let data = try checkpointTestImageData()

        do {
            _ = try await fixture.makeService(
                scopeProvider: FixedMediumUploadScopeProvider("session-a")
            ).uploadImageData(data)
        } catch {
            #expect(error is URLError)
        }

        _ = try await fixture.makeService(
            scopeProvider: FixedMediumUploadScopeProvider("session-b")
        ).uploadImageData(data)

        #expect(fixture.transport.snapshot().startRequests == 2)
        #expect(await fixture.controller.snapshotRequestCount() == 2)
        #expect(fixture.transport.snapshot().finishUploadIDs.suffix(1) == ["upload-2"])
        let sessionAKey = try fixture.checkpointKey(data: data, scopeIdentifier: "session-a")
        #expect(try await fixture.makeStore().loadCheckpoint(for: sessionAKey)?.state == .finishPending)
    }

    @Test
    func differentPayloadFingerprintDoesNotReuseCheckpoint() async throws {
        let fixture = MediumUploadCheckpointFixture(
            finishSteps: [.transientFailure, .transientFailure, .transientFailure, .success]
        )
        let firstData = try checkpointTestImageData()
        let secondData = try checkpointAlternateImageData()
        let provider = FixedMediumUploadScopeProvider("session-a")

        do {
            _ = try await fixture.makeService(scopeProvider: provider).uploadImageData(firstData)
        } catch {
            #expect(error is URLError)
        }

        _ = try await fixture.makeService(scopeProvider: provider).uploadImageData(secondData)

        #expect(fixture.transport.snapshot().startRequests == 2)
        #expect(await fixture.controller.snapshotRequestCount() == 2)
        #expect(fixture.transport.snapshot().finishUploadIDs.suffix(1) == ["upload-2"])
    }

    @Test
    func expiredCheckpointFailsExplicitlyBeforeStartingAnotherUpload() async throws {
        let fixture = MediumUploadCheckpointFixture(finishSteps: [.success])
        let data = try checkpointTestImageData()
        let scopeIdentifier = "session-a"
        let key = try fixture.checkpointKey(data: data, scopeIdentifier: scopeIdentifier)
        let checkpoint = try MediumUploadCheckpoint(
            key: key,
            uploadID: "expired-upload",
            uploadURL: #require(URL(string: "https://expired.example/upload")),
            method: "PUT",
            headers: [],
            expiresAt: .distantPast,
            state: .finishPending
        )
        let store = fixture.makeStore()
        try await store.saveCheckpoint(checkpoint)

        do {
            _ = try await fixture.makeService(
                scopeProvider: FixedMediumUploadScopeProvider(scopeIdentifier)
            ).uploadImageData(data)
            Issue.record("Expected an explicit expired-checkpoint error")
        } catch let error as MediumUploadError {
            guard case .checkpointExpired = error else {
                Issue.record("Expected checkpointExpired, received \(error)")
                return
            }
        }

        #expect(fixture.transport.snapshot().startRequests == 0)
        #expect(await fixture.controller.snapshotRequestCount() == 0)
        #expect(try await store.loadCheckpoint(for: key) == nil)
    }

    @Test
    func corruptCheckpointFileFailsExplicitlyWithoutStartingNetwork() async throws {
        let fixture = MediumUploadCheckpointFixture(finishSteps: [.success])
        try FileManager.default.createDirectory(
            at: fixture.checkpointFileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("not-json".utf8).write(to: fixture.checkpointFileURL)

        do {
            _ = try await fixture.makeService(
                scopeProvider: FixedMediumUploadScopeProvider("session-a")
            ).uploadImageData(checkpointTestImageData())
            Issue.record("Expected an explicit corrupt-checkpoint error")
        } catch let error as MediumUploadError {
            guard case .checkpointCorrupt = error else {
                Issue.record("Expected checkpointCorrupt, received \(error)")
                return
            }
        }

        #expect(fixture.transport.snapshot().startRequests == 0)
        #expect(await fixture.controller.snapshotRequestCount() == 0)
    }

    @Test
    func checkpointWriteFailureStopsBeforePUTWithExplicitSafetyError() async throws {
        let fixture = MediumUploadCheckpointFixture(finishSteps: [.success])
        let failingStore = FailingMediumUploadCheckpointStore()

        do {
            _ = try await fixture.makeService(
                scopeProvider: FixedMediumUploadScopeProvider("session-a"),
                checkpointStore: failingStore
            ).uploadImageData(checkpointTestImageData())
            Issue.record("Expected checkpoint persistence to fail safely")
        } catch let error as MediumUploadError {
            guard case .checkpointPersistenceFailed = error else {
                Issue.record("Expected checkpointPersistenceFailed, received \(error)")
                return
            }
        }

        #expect(fixture.transport.snapshot().startRequests == 1)
        #expect(await fixture.controller.snapshotRequestCount() == 0)
        #expect(fixture.transport.snapshot().finishUploadIDs.isEmpty)
    }
}

private func checkpointAlternateImageData() throws -> Data {
    let encodedGIF = "R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw=="
    guard let data = Data(base64Encoded: encodedGIF) else {
        throw ImagePayloadError.invalidImage
    }
    return data
}
