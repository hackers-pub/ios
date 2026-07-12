import Foundation
@testable import HackersPub
import Testing

private actor ExpiringOnUploadCheckpointStore: MediumUploadCheckpointStore {
    private let underlying: any MediumUploadCheckpointStore
    private let clock: MutableMediumUploadClock
    private let interval: TimeInterval

    init(
        underlying: any MediumUploadCheckpointStore,
        clock: MutableMediumUploadClock,
        interval: TimeInterval
    ) {
        self.underlying = underlying
        self.clock = clock
        self.interval = interval
    }

    func loadCheckpoint(for key: MediumUploadCheckpointKey) async throws -> MediumUploadCheckpoint? {
        try await underlying.loadCheckpoint(for: key)
    }

    func saveCheckpoint(_ checkpoint: MediumUploadCheckpoint) async throws {
        try await underlying.saveCheckpoint(checkpoint)
        if checkpoint.state == .uploading {
            clock.advance(by: interval)
        }
    }

    func removeCheckpoint(for key: MediumUploadCheckpointKey) async throws {
        try await underlying.removeCheckpoint(for: key)
    }
}

@Suite(.serialized)
struct MediumUploadExpiryTests {
    @Test
    func expiryAfterCheckpointPersistenceStopsBeforeTheFirstPUT() async throws {
        let clock = MutableMediumUploadClock()
        let fixture = MediumUploadCheckpointFixture(
            finishSteps: [.success],
            clock: clock,
            startUploadTTL: 60
        )
        let data = try checkpointTestImageData()
        let scopeIdentifier = "session-a"
        let key = try fixture.checkpointKey(data: data, scopeIdentifier: scopeIdentifier)
        let store = ExpiringOnUploadCheckpointStore(
            underlying: fixture.makeStore(),
            clock: clock,
            interval: 60
        )

        do {
            _ = try await fixture.makeService(
                scopeProvider: FixedMediumUploadScopeProvider(scopeIdentifier),
                checkpointStore: store
            ).uploadImageData(data)
            Issue.record("Expected target expiry before PUT")
        } catch let error as MediumUploadError {
            guard case .checkpointExpired = error else {
                Issue.record("Expected checkpointExpired, received \(error)")
                return
            }
        }

        #expect(await fixture.controller.snapshotRequestCount() == 0)
        #expect(try await fixture.makeStore().loadCheckpoint(for: key) == nil)
    }

    @Test
    func expiryAfterATransientPUTFailureStopsTheRetryBeforeNetworkAccess() async throws {
        let clock = MutableMediumUploadClock()
        let fixture = MediumUploadCheckpointFixture(
            finishSteps: [.success],
            uploadBehavior: .respond(statusCode: 503),
            clock: clock,
            startUploadTTL: 60
        )
        let data = try checkpointTestImageData()
        let scopeIdentifier = "session-a"
        let key = try fixture.checkpointKey(data: data, scopeIdentifier: scopeIdentifier)
        await fixture.controller.advanceClockOnNextRequest(clock, by: 60)

        do {
            _ = try await fixture.makeService(
                scopeProvider: FixedMediumUploadScopeProvider(scopeIdentifier)
            ).uploadImageData(data)
            Issue.record("Expected target expiry before retry PUT")
        } catch let error as MediumUploadError {
            guard case .checkpointExpired = error else {
                Issue.record("Expected checkpointExpired, received \(error)")
                return
            }
        }

        #expect(await fixture.controller.snapshotRequestCount() == 1)
        #expect(try await fixture.makeStore().loadCheckpoint(for: key) == nil)
    }
}
