import Foundation
@testable import HackersPub
import Testing

private actor RemoveFailingCheckpointStore: MediumUploadCheckpointStore {
    enum Failure: Error {
        case removalDenied
    }

    private let underlying: any MediumUploadCheckpointStore

    init(underlying: any MediumUploadCheckpointStore) {
        self.underlying = underlying
    }

    func loadCheckpoint(for key: MediumUploadCheckpointKey) async throws -> MediumUploadCheckpoint? {
        try await underlying.loadCheckpoint(for: key)
    }

    func saveCheckpoint(_ checkpoint: MediumUploadCheckpoint) async throws {
        try await underlying.saveCheckpoint(checkpoint)
    }

    func removeCheckpoint(for _: MediumUploadCheckpointKey) async throws {
        throw Failure.removalDenied
    }
}

@Suite(.serialized)
// swiftlint:disable:next type_body_length
struct MediumUploadTargetValidityTests {
    @Test
    func freshExpiredTargetFailsBeforePUT() async throws {
        let fixture = MediumUploadCheckpointFixture(
            finishSteps: [.success],
            startUploadTTL: -1
        )
        let data = try checkpointTestImageData()
        let scopeIdentifier = "session-a"

        do {
            _ = try await fixture.makeService(
                scopeProvider: FixedMediumUploadScopeProvider(scopeIdentifier)
            ).uploadImageData(data)
            Issue.record("Expected the fresh expired target to be rejected")
        } catch let error as MediumUploadError {
            guard case .checkpointExpired = error else {
                Issue.record("Expected checkpointExpired, received \(error)")
                return
            }
        }

        let key = try fixture.checkpointKey(data: data, scopeIdentifier: scopeIdentifier)
        #expect(fixture.transport.snapshot().startRequests == 1)
        #expect(await fixture.controller.snapshotRequestCount() == 0)
        #expect(fixture.transport.snapshot().finishUploadIDs.isEmpty)
        #expect(try await fixture.makeStore().loadCheckpoint(for: key) == nil)
    }

    @Test
    func unusableTargetIsDiscardedAndTheNextCallStartsFresh() async throws {
        let fixture = MediumUploadCheckpointFixture(
            finishSteps: [.success],
            uploadBehavior: .respond(statusCode: 403)
        )
        let data = try checkpointTestImageData()
        let scopeIdentifier = "session-a"
        let provider = FixedMediumUploadScopeProvider(scopeIdentifier)

        do {
            _ = try await fixture.makeService(scopeProvider: provider).uploadImageData(data)
            Issue.record("Expected the unusable target to fail explicitly")
        } catch let error as MediumUploadError {
            guard case .uploadTargetInvalid(403) = error else {
                Issue.record("Expected uploadTargetInvalid(403), received \(error)")
                return
            }
        }

        let key = try fixture.checkpointKey(data: data, scopeIdentifier: scopeIdentifier)
        #expect(try await fixture.makeStore().loadCheckpoint(for: key) == nil)

        await fixture.controller.setBehavior(.succeed)
        let medium = try await fixture.makeService(scopeProvider: provider).uploadImageData(data)

        #expect(medium.id == "medium-upload-2")
        #expect(fixture.transport.snapshot().startRequests == 2)
        #expect(await fixture.controller.snapshotRequestCount() == 2)
        #expect(fixture.transport.snapshot().finishUploadIDs == ["upload-2"])
    }

    @Test
    func transientTargetFailureRetainsTheSameTargetForRetry() async throws {
        let fixture = MediumUploadCheckpointFixture(
            finishSteps: [.success],
            uploadBehavior: .respond(statusCode: 503)
        )
        let data = try checkpointTestImageData()
        let scopeIdentifier = "session-a"
        let provider = FixedMediumUploadScopeProvider(scopeIdentifier)

        do {
            _ = try await fixture.makeService(scopeProvider: provider).uploadImageData(data)
            Issue.record("Expected bounded transient PUT retries to fail")
        } catch let error as MediumUploadError {
            guard case .uploadTargetFailed(503) = error else {
                Issue.record("Expected uploadTargetFailed(503), received \(error)")
                return
            }
        }

        let key = try fixture.checkpointKey(data: data, scopeIdentifier: scopeIdentifier)
        #expect(try await fixture.makeStore().loadCheckpoint(for: key)?.state == .uploading)

        await fixture.controller.setBehavior(.succeed)
        _ = try await fixture.makeService(scopeProvider: provider).uploadImageData(data)

        #expect(fixture.transport.snapshot().startRequests == 1)
        #expect(await fixture.controller.snapshotRequestCount() == 4)
        #expect(fixture.transport.snapshot().finishUploadIDs == ["upload-1"])
    }

    @Test
    func exactExpiryBoundaryUsesTheInjectedClock() async throws {
        let clock = MutableMediumUploadClock()
        let fixture = MediumUploadCheckpointFixture(
            finishSteps: [.success],
            uploadBehavior: .suspendBeforeResponse,
            clock: clock,
            startUploadTTL: 60
        )
        let data = try checkpointTestImageData()
        let scopeIdentifier = "session-a"
        let provider = FixedMediumUploadScopeProvider(scopeIdentifier)
        let owner = Task {
            try await fixture.makeService(scopeProvider: provider).uploadImageData(data)
        }

        await fixture.controller.waitForRequestCount(1)
        owner.cancel()
        await fixture.controller.setBehavior(.succeed)
        await fixture.controller.releaseAll()
        _ = try? await owner.value

        clock.advance(by: 60)

        do {
            _ = try await fixture.makeService(scopeProvider: provider).uploadImageData(data)
            Issue.record("Expected the target to expire exactly at its boundary")
        } catch let error as MediumUploadError {
            guard case .checkpointExpired = error else {
                Issue.record("Expected checkpointExpired, received \(error)")
                return
            }
        }

        #expect(fixture.transport.snapshot().startRequests == 1)
        #expect(await fixture.controller.snapshotRequestCount() == 1)
        #expect(fixture.transport.snapshot().finishUploadIDs.isEmpty)
    }

    @Test
    func blankScopeIsRejectedBeforeCheckpointOrNetworkAccess() async throws {
        let fixture = MediumUploadCheckpointFixture(finishSteps: [.success])
        let store = RecordingMediumUploadCheckpointStore()

        do {
            _ = try await fixture.makeService(
                scopeProvider: FixedMediumUploadScopeProvider(" \n\t "),
                checkpointStore: store
            ).uploadImageData(checkpointTestImageData())
            Issue.record("Expected a blank upload scope to be rejected")
        } catch let error as MediumUploadError {
            guard case .notAuthenticated = error else {
                Issue.record("Expected notAuthenticated, received \(error)")
                return
            }
        }

        #expect(await store.snapshotAccessCount() == 0)
        #expect(fixture.transport.snapshot().startRequests == 0)
        #expect(await fixture.controller.snapshotRequestCount() == 0)
    }

    @Test
    func invalidMethodCheckpointIsQuarantinedBeforeNetworkAndTheNextAttemptStartsFresh() async throws {
        let fixture = MediumUploadCheckpointFixture(finishSteps: [.success])
        let data = try checkpointTestImageData()
        let scopeIdentifier = "session-a"
        let key = try fixture.checkpointKey(data: data, scopeIdentifier: scopeIdentifier)
        let store = fixture.makeStore()
        try await store.saveCheckpoint(
            corruptCheckpoint(
                key: key,
                uploadURL: #require(URL(string: "https://checkpoint.example/upload")),
                method: "POST"
            )
        )

        try await assertCorruptCheckpointIsQuarantined(
            fixture: fixture,
            store: store,
            key: key,
            scopeIdentifier: scopeIdentifier,
            data: data
        )
    }

    @Test
    func hostlessHTTPSCheckpointIsQuarantinedBeforeNetworkAndTheNextAttemptStartsFresh() async throws {
        let fixture = MediumUploadCheckpointFixture(finishSteps: [.success])
        let data = try checkpointTestImageData()
        let scopeIdentifier = "session-a"
        let key = try fixture.checkpointKey(data: data, scopeIdentifier: scopeIdentifier)
        let store = fixture.makeStore()
        try await store.saveCheckpoint(
            corruptCheckpoint(
                key: key,
                uploadURL: #require(URL(string: "https:/missing-host")),
                method: "PUT"
            )
        )

        try await assertCorruptCheckpointIsQuarantined(
            fixture: fixture,
            store: store,
            key: key,
            scopeIdentifier: scopeIdentifier,
            data: data
        )
    }

    @Test
    func completedCheckpointWithoutAMediumIsQuarantinedBeforeNetworkAndTheNextAttemptStartsFresh() async throws {
        let fixture = MediumUploadCheckpointFixture(finishSteps: [.success])
        let data = try checkpointTestImageData()
        let scopeIdentifier = "session-a"
        let key = try fixture.checkpointKey(data: data, scopeIdentifier: scopeIdentifier)
        let store = fixture.makeStore()
        try await store.saveCheckpoint(
            MediumUploadCheckpoint(
                key: key,
                uploadID: "completed-upload",
                uploadURL: #require(URL(string: "https://checkpoint.example/upload")),
                method: "PUT",
                headers: [],
                expiresAt: .distantFuture,
                state: .completed
            )
        )

        try await assertCorruptCheckpointIsQuarantined(
            fixture: fixture,
            store: store,
            key: key,
            scopeIdentifier: scopeIdentifier,
            data: data
        )
    }

    @Test
    func corruptCheckpointRemovalFailureFailsClosedBeforeNetworkAccess() async throws {
        let fixture = MediumUploadCheckpointFixture(finishSteps: [.success])
        let data = try checkpointTestImageData()
        let scopeIdentifier = "session-a"
        let key = try fixture.checkpointKey(data: data, scopeIdentifier: scopeIdentifier)
        let fileStore = fixture.makeStore()
        try await fileStore.saveCheckpoint(
            corruptCheckpoint(
                key: key,
                uploadURL: #require(URL(string: "https://checkpoint.example/upload")),
                method: "POST"
            )
        )

        do {
            _ = try await fixture.makeService(
                scopeProvider: FixedMediumUploadScopeProvider(scopeIdentifier),
                checkpointStore: RemoveFailingCheckpointStore(underlying: fileStore)
            ).uploadImageData(data)
            Issue.record("Expected failed corrupt-checkpoint cleanup to fail closed")
        } catch let error as MediumUploadError {
            guard case .checkpointPersistenceFailed = error else {
                Issue.record("Expected checkpointPersistenceFailed, received \(error)")
                return
            }
        }

        #expect(fixture.transport.snapshot().startRequests == 0)
        #expect(await fixture.controller.snapshotRequestCount() == 0)
    }

    private func corruptCheckpoint(
        key: MediumUploadCheckpointKey,
        uploadURL: URL,
        method: String
    ) -> MediumUploadCheckpoint {
        MediumUploadCheckpoint(
            key: key,
            uploadID: "corrupt-upload",
            uploadURL: uploadURL,
            method: method,
            headers: [],
            expiresAt: .distantFuture,
            state: .started
        )
    }

    private func assertCorruptCheckpointIsQuarantined(
        fixture: MediumUploadCheckpointFixture,
        store: FileMediumUploadCheckpointStore,
        key: MediumUploadCheckpointKey,
        scopeIdentifier: String,
        data: Data
    ) async throws {
        do {
            _ = try await fixture.makeService(
                scopeProvider: FixedMediumUploadScopeProvider(scopeIdentifier)
            ).uploadImageData(data)
            Issue.record("Expected a semantic checkpoint corruption error")
        } catch let error as MediumUploadError {
            guard case .checkpointCorrupt = error else {
                Issue.record("Expected checkpointCorrupt, received \(error)")
                return
            }
        } catch {
            Issue.record("Expected checkpointCorrupt, received \(error)")
        }

        #expect(try await store.loadCheckpoint(for: key) == nil)
        #expect(fixture.transport.snapshot().startRequests == 0)
        #expect(await fixture.controller.snapshotRequestCount() == 0)

        do {
            _ = try await fixture.makeService(
                scopeProvider: FixedMediumUploadScopeProvider(scopeIdentifier)
            ).uploadImageData(data)
        } catch {
            Issue.record("Expected a fresh upload after corrupt-checkpoint quarantine: \(error)")
        }

        #expect(fixture.transport.snapshot().startRequests == 1)
        #expect(await fixture.controller.snapshotRequestCount() == 1)
    }
}
