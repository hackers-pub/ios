import Foundation
@testable import HackersPub
import Testing

private actor OneShotRemoveFailingCheckpointStore: MediumUploadCheckpointStore {
    enum Failure: Error {
        case removeDenied
    }

    private let underlying: any MediumUploadCheckpointStore
    private var shouldFailRemove = true

    init(underlying: any MediumUploadCheckpointStore) {
        self.underlying = underlying
    }

    func loadCheckpoint(for key: MediumUploadCheckpointKey) async throws -> MediumUploadCheckpoint? {
        try await underlying.loadCheckpoint(for: key)
    }

    func saveCheckpoint(_ checkpoint: MediumUploadCheckpoint) async throws {
        try await underlying.saveCheckpoint(checkpoint)
    }

    func removeCheckpoint(for key: MediumUploadCheckpointKey) async throws {
        if shouldFailRemove {
            shouldFailRemove = false
            throw Failure.removeDenied
        }
        try await underlying.removeCheckpoint(for: key)
    }
}

private actor CompletedSaveFailingCheckpointStore: MediumUploadCheckpointStore {
    enum Failure: Error {
        case writeDenied
    }

    private let underlying: any MediumUploadCheckpointStore
    private var removeCount = 0

    init(underlying: any MediumUploadCheckpointStore) {
        self.underlying = underlying
    }

    func loadCheckpoint(for key: MediumUploadCheckpointKey) async throws -> MediumUploadCheckpoint? {
        try await underlying.loadCheckpoint(for: key)
    }

    func saveCheckpoint(_ checkpoint: MediumUploadCheckpoint) async throws {
        guard checkpoint.state != .completed else {
            throw Failure.writeDenied
        }
        try await underlying.saveCheckpoint(checkpoint)
    }

    func removeCheckpoint(for key: MediumUploadCheckpointKey) async throws {
        removeCount += 1
        try await underlying.removeCheckpoint(for: key)
    }

    func snapshotRemoveCount() -> Int {
        removeCount
    }
}

@Suite(.serialized)
struct MediumUploadCompletionReplayTests {
    @Test
    func removeFailureReplaysCompletedResultAfterServiceAndStoreRecreation() async throws {
        let fixture = MediumUploadCheckpointFixture(finishSteps: [.success])
        let data = try checkpointTestImageData()
        let scopeIdentifier = "session-sensitive-value"
        let provider = FixedMediumUploadScopeProvider(scopeIdentifier)
        let key = try fixture.checkpointKey(data: data, scopeIdentifier: scopeIdentifier)
        let fileStore = fixture.makeStore()
        let firstStore = OneShotRemoveFailingCheckpointStore(underlying: fileStore)

        let firstResult = try await fixture.makeService(
            scopeProvider: provider,
            checkpointStore: firstStore
        ).uploadImageData(data)

        #expect(firstResult.id == "medium-upload-1")
        #expect(fixture.transport.snapshot().startRequests == 1)
        #expect(await fixture.controller.snapshotRequestCount() == 1)
        #expect(fixture.transport.snapshot().finishUploadIDs == ["upload-1"])

        let tombstone = try #require(try await fileStore.loadCheckpoint(for: key))
        #expect(tombstone.state == .completed)
        #expect(tombstone.completedMedium == firstResult)

        let serialized = try String(contentsOf: fixture.checkpointFileURL, encoding: .utf8)
        #expect(!serialized.contains(scopeIdentifier))
        #expect(!serialized.contains(data.base64EncodedString()))

        fixture.clock.advance(by: fixture.startUploadTTL + 1)

        let replayedResult = try await fixture.makeService(
            scopeProvider: provider,
            checkpointStore: fixture.makeStore()
        ).uploadImageData(data)

        #expect(replayedResult == firstResult)
        #expect(fixture.transport.snapshot().startRequests == 1)
        #expect(await fixture.controller.snapshotRequestCount() == 1)
        #expect(fixture.transport.snapshot().finishUploadIDs == ["upload-1"])
        #expect(try await fixture.makeStore().loadCheckpoint(for: key) == nil)
    }

    @Test
    func completedPersistenceFailureRetainsFinishPendingAndSkipsCleanup() async throws {
        let fixture = MediumUploadCheckpointFixture(finishSteps: [.success])
        let data = try checkpointTestImageData()
        let scopeIdentifier = "session-a"
        let key = try fixture.checkpointKey(data: data, scopeIdentifier: scopeIdentifier)
        let store = CompletedSaveFailingCheckpointStore(underlying: fixture.makeStore())

        do {
            _ = try await fixture.makeService(
                scopeProvider: FixedMediumUploadScopeProvider(scopeIdentifier),
                checkpointStore: store
            ).uploadImageData(data)
            Issue.record("Expected completed checkpoint persistence to fail closed")
        } catch let error as MediumUploadError {
            guard case .checkpointPersistenceFailed = error else {
                Issue.record("Expected checkpointPersistenceFailed, received \(error)")
                return
            }
        }

        #expect(try await fixture.makeStore().loadCheckpoint(for: key)?.state == .finishPending)
        #expect(await store.snapshotRemoveCount() == 0)
        #expect(fixture.transport.snapshot().startRequests == 1)
        #expect(await fixture.controller.snapshotRequestCount() == 1)
        #expect(fixture.transport.snapshot().finishUploadIDs == ["upload-1"])
    }
}
