import Apollo
import Foundation
@testable import HackersPub

final class MutableMediumUploadClock: MediumUploadClock, @unchecked Sendable {
    private let lock = NSLock()
    private var value: Date

    init(now: Date = Date(timeIntervalSince1970: 1_800_000_000)) {
        value = now
    }

    func now() -> Date {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func advance(by interval: TimeInterval) {
        lock.lock()
        value = value.addingTimeInterval(interval)
        lock.unlock()
    }
}

struct FixedMediumUploadScopeProvider: MediumUploadScopeProviding {
    let scope: MediumUploadCheckpointScope

    init(_ identifier: String) {
        scope = MediumUploadCheckpointScope(accountOrSessionIdentifier: identifier)
    }

    func currentScope() async throws -> MediumUploadCheckpointScope {
        scope
    }
}

actor ObservedMediumUploadScopeProvider: MediumUploadScopeProviding {
    private let scope: MediumUploadCheckpointScope
    private var requestCount = 0
    private var waiters: [(expected: Int, continuation: CheckedContinuation<Void, Never>)] = []

    init(_ identifier: String) {
        scope = MediumUploadCheckpointScope(accountOrSessionIdentifier: identifier)
    }

    func currentScope() async throws -> MediumUploadCheckpointScope {
        requestCount += 1
        let ready = waiters.filter { requestCount >= $0.expected }
        waiters.removeAll { requestCount >= $0.expected }
        ready.forEach { $0.continuation.resume() }
        return scope
    }

    func waitForRequestCount(_ expected: Int) async {
        guard requestCount < expected else { return }
        await withCheckedContinuation { continuation in
            waiters.append((expected, continuation))
        }
    }
}

actor FailingMediumUploadCheckpointStore: MediumUploadCheckpointStore {
    enum Failure: Error {
        case writeDenied
    }

    func loadCheckpoint(for _: MediumUploadCheckpointKey) async throws -> MediumUploadCheckpoint? {
        nil
    }

    func saveCheckpoint(_: MediumUploadCheckpoint) async throws {
        throw Failure.writeDenied
    }

    func removeCheckpoint(for _: MediumUploadCheckpointKey) async throws {}
}

actor RecordingMediumUploadCheckpointStore: MediumUploadCheckpointStore {
    private var accessCount = 0

    func loadCheckpoint(for _: MediumUploadCheckpointKey) async throws -> MediumUploadCheckpoint? {
        accessCount += 1
        return nil
    }

    func saveCheckpoint(_: MediumUploadCheckpoint) async throws {
        accessCount += 1
    }

    func removeCheckpoint(for _: MediumUploadCheckpointKey) async throws {
        accessCount += 1
    }

    func snapshotAccessCount() -> Int {
        accessCount
    }
}

struct MediumUploadCheckpointFixture {
    let checkpointFileURL: URL
    let controller: CheckpointUploadRequestController
    let transport: CheckpointUploadNetworkTransport
    let client: ApolloClient
    let session: URLSession
    let clock: MutableMediumUploadClock
    let startUploadTTL: TimeInterval

    init(
        finishSteps: [CheckpointUploadNetworkTransport.FinishStep],
        uploadBehavior: CheckpointUploadRequestController.Behavior = .succeed,
        clock: MutableMediumUploadClock = MutableMediumUploadClock(),
        startUploadTTL: TimeInterval = 60 * 60
    ) {
        let identifier = UUID().uuidString
        checkpointFileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("medium-upload-checkpoints-\(identifier)", isDirectory: true)
            .appendingPathComponent("checkpoints.json")
        let host = "checkpoint-upload-\(identifier).example"
        controller = CheckpointUploadRequestController(behavior: uploadBehavior)
        CheckpointUploadURLProtocol.register(controller, for: host)
        self.clock = clock
        self.startUploadTTL = startUploadTTL
        transport = CheckpointUploadNetworkTransport(
            uploadHost: host,
            finishSteps: finishSteps,
            clock: clock,
            startUploadTTL: startUploadTTL
        )
        client = ApolloClient(
            networkTransport: transport,
            store: ApolloStore(cache: InMemoryNormalizedCache())
        )
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CheckpointUploadURLProtocol.self]
        session = URLSession(configuration: configuration)
    }

    func makeStore() -> FileMediumUploadCheckpointStore {
        FileMediumUploadCheckpointStore(fileURL: checkpointFileURL, clock: clock)
    }

    func makeService(
        scopeProvider: any MediumUploadScopeProviding,
        checkpointStore: (any MediumUploadCheckpointStore)? = nil
    ) -> MediumUploadService {
        MediumUploadService(
            client: client,
            session: session,
            checkpointStore: checkpointStore ?? makeStore(),
            scopeProvider: scopeProvider,
            clock: clock
        )
    }

    func checkpointKey(data: Data, scopeIdentifier: String) throws -> MediumUploadCheckpointKey {
        let payload = try ImagePayloadPolicy.payload(from: data)
        return MediumUploadCheckpointKey(
            scope: MediumUploadCheckpointScope(accountOrSessionIdentifier: scopeIdentifier),
            contentType: payload.contentType,
            data: payload.data
        )
    }
}

func checkpointTestImageData() throws -> Data {
    let encodedPNG = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8A" +
        "AusB9Y9JZYkAAAAASUVORK5CYII="
    guard let data = Data(base64Encoded: encodedPNG) else {
        throw ImagePayloadError.invalidImage
    }
    return data
}
