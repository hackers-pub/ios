import Apollo
import ApolloAPI
import Foundation
@testable import HackersPub
import Testing

private class CountingUploadURLProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    private static var requestCounts: [String: Int] = [:]

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host?.hasPrefix("upload-") == true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url,
              let host = url.host,
              let response = HTTPURLResponse(
                  url: url,
                  statusCode: 200,
                  httpVersion: nil,
                  headerFields: nil
              )
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        Self.lock.lock()
        Self.requestCounts[host, default: 0] += 1
        Self.lock.unlock()

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    static func reset(host: String) {
        lock.lock()
        requestCounts[host] = 0
        lock.unlock()
    }

    static func requestCount(for host: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return requestCounts[host, default: 0]
    }
}

private final class MediumUploadNetworkTransport: NetworkTransport, @unchecked Sendable {
    enum FinishStep {
        case transientFailure
        case cancellation
        case success
        case invalidInput
    }

    private let lock = NSLock()
    private let uploadURL: String
    private let clock: any MediumUploadClock
    private let startUploadTTL: TimeInterval
    private var finishSteps: [FinishStep]
    private var startRequestCount = 0
    private var finishUploadIDs: [String] = []
    private var generatedAltTextRequestCount = 0

    init(
        uploadURL: String,
        finishSteps: [FinishStep],
        clock: any MediumUploadClock,
        startUploadTTL: TimeInterval
    ) {
        self.uploadURL = uploadURL
        self.finishSteps = finishSteps
        self.clock = clock
        self.startUploadTTL = startUploadTTL
    }

    func send<Query: GraphQLQuery>(
        query: Query,
        fetchBehavior _: FetchBehavior,
        requestConfiguration _: RequestConfiguration
    ) throws -> AsyncThrowingStream<GraphQLResponse<Query>, any Error> {
        if query is HackersPub.GeneratedAltTextQuery {
            lock.lock()
            generatedAltTextRequestCount += 1
            lock.unlock()
            return responseStream(data: generatedAltTextResponse())
        }
        return failingStream(URLError(.unsupportedURL))
    }

    func send<Mutation: GraphQLMutation>(
        mutation: Mutation,
        requestConfiguration _: RequestConfiguration
    ) throws -> AsyncThrowingStream<GraphQLResponse<Mutation>, any Error> {
        if mutation is HackersPub.StartMediumUploadMutation {
            lock.lock()
            startRequestCount += 1
            lock.unlock()
            return responseStream(data: startUploadResponse())
        }

        if let mutation = mutation as? HackersPub.FinishMediumUploadMutation {
            let step: FinishStep
            lock.lock()
            finishUploadIDs.append(mutation.uploadId)
            step = finishSteps.isEmpty ? .success : finishSteps.removeFirst()
            lock.unlock()

            switch step {
            case .transientFailure:
                return failingStream(URLError(.timedOut))
            case .cancellation:
                return failingStream(CancellationError())
            case .success:
                return responseStream(data: finishUploadResponse())
            case .invalidInput:
                return responseStream(data: invalidFinishResponse())
            }
        }

        return failingStream(URLError(.unsupportedURL))
    }

    func snapshot() -> (startRequests: Int, finishUploadIDs: [String], generatedAltTextRequests: Int) {
        lock.lock()
        defer { lock.unlock() }
        return (startRequestCount, finishUploadIDs, generatedAltTextRequestCount)
    }

    private func responseStream<Operation: GraphQLOperation>(
        data: [String: Any]
    ) -> AsyncThrowingStream<GraphQLResponse<Operation>, any Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let responseData = try await Operation.Data(data: data)
                    continuation.yield(
                        GraphQLResponse(
                            data: responseData,
                            extensions: nil,
                            errors: nil,
                            source: .server,
                            dependentKeys: nil
                        )
                    )
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func failingStream<Operation: GraphQLOperation>(
        _ error: any Error
    ) -> AsyncThrowingStream<GraphQLResponse<Operation>, any Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: error)
        }
    }

    private func startUploadResponse() -> [String: Any] {
        let expiresAt = clock.now().addingTimeInterval(startUploadTTL)
        return [
            "startMediumUpload": [
                "__typename": "StartMediumUploadPayload",
                "uploadId": "upload-1",
                "uploadUrl": uploadURL,
                "method": "PUT",
                "headers": [],
                "expires": ISO8601DateFormatter().string(from: expiresAt)
            ]
        ]
    }

    private func finishUploadResponse() -> [String: Any] {
        [
            "finishMediumUpload": [
                "__typename": "FinishMediumUploadPayload",
                "medium": [
                    "__typename": "Medium",
                    "id": "Medium:medium-1",
                    "uuid": "medium-1",
                    "url": "https://hackers.pub/media/medium-1",
                    "type": "image/png",
                    "width": 1,
                    "height": 1
                ]
            ]
        ]
    }

    private func invalidFinishResponse() -> [String: Any] {
        [
            "finishMediumUpload": [
                "__typename": "InvalidInputError",
                "inputPath": "uploadId"
            ]
        ]
    }

    private func generatedAltTextResponse() -> [String: Any] {
        [
            "node": [
                "__typename": "Medium",
                "generatedAltText": "  A waterfall surrounded by green cliffs.  "
            ]
        ]
    }
}

private struct MediumUploadFixture {
    let service: MediumUploadService
    let transport: MediumUploadNetworkTransport
    let host: String
}

struct MediumUploadServiceIntegrationTests {
    @Test
    func generatesAndTrimsAltTextForAnUploadedMedium() async throws {
        let fixture = makeFixture(finishSteps: [.success])
        let medium = try await fixture.service.uploadImageData(imageData())
        let nodeID = try #require(medium.nodeID)

        let altText = try await fixture.service.generateAltText(
            mediumNodeID: nodeID,
            language: "en",
            context: "Waterfalls"
        )

        #expect(altText == "A waterfall surrounded by green cliffs.")
        #expect(fixture.transport.snapshot().generatedAltTextRequests == 1)
    }

    @Test
    func retriesTransientFinishAfterTheUploadBodyWasPutOnce() async throws {
        let fixture = makeFixture(finishSteps: [.transientFailure, .success])

        let medium = try await fixture.service.uploadImageData(imageData())

        #expect(medium.id == "medium-1")
        #expect(fixture.transport.snapshot().startRequests == 1)
        #expect(fixture.transport.snapshot().finishUploadIDs == ["upload-1", "upload-1"])
        #expect(CountingUploadURLProtocol.requestCount(for: fixture.host) == 1)
    }

    @Test
    func exhaustedFinishRetryResumesTheSameUploadedMediumWithoutAnotherPut() async throws {
        let fixture = makeFixture(
            finishSteps: [.transientFailure, .transientFailure, .transientFailure, .success]
        )
        let data = try imageData()

        do {
            _ = try await fixture.service.uploadImageData(data)
            Issue.record("Expected bounded finish retries to surface a transient failure")
        } catch {
            // The next caller retry must finalize the previously uploaded medium.
        }

        let medium = try await fixture.service.uploadImageData(data)

        #expect(medium.id == "medium-1")
        #expect(fixture.transport.snapshot().startRequests == 1)
        #expect(
            fixture.transport.snapshot().finishUploadIDs ==
                ["upload-1", "upload-1", "upload-1", "upload-1"]
        )
        #expect(CountingUploadURLProtocol.requestCount(for: fixture.host) == 1)
    }

    @Test
    func cancelledFinishResumesTheSameUploadedMediumWithoutAnotherPut() async throws {
        let fixture = makeFixture(finishSteps: [.cancellation, .success])
        let data = try imageData()

        do {
            _ = try await fixture.service.uploadImageData(data)
            Issue.record("Expected the cancelled finish mutation to leave a resumable upload")
        } catch is CancellationError {
            // Cancellation must retain the uploaded medium for the next retry.
        }

        let medium = try await fixture.service.uploadImageData(data)

        #expect(medium.id == "medium-1")
        #expect(fixture.transport.snapshot().startRequests == 1)
        #expect(fixture.transport.snapshot().finishUploadIDs == ["upload-1", "upload-1"])
        #expect(CountingUploadURLProtocol.requestCount(for: fixture.host) == 1)
    }

    @Test
    func permanentFinishPayloadErrorsAreNotRetried() async throws {
        let fixture = makeFixture(finishSteps: [.invalidInput, .success])

        do {
            _ = try await fixture.service.uploadImageData(imageData())
            Issue.record("Expected a permanent finish payload error")
        } catch let error as MediumUploadError {
            guard case .invalidInput("uploadId") = error else {
                Issue.record("Expected invalid input, received \(error)")
                return
            }
        }

        #expect(fixture.transport.snapshot().startRequests == 1)
        #expect(fixture.transport.snapshot().finishUploadIDs == ["upload-1"])
        #expect(CountingUploadURLProtocol.requestCount(for: fixture.host) == 1)
    }

    private func makeFixture(
        finishSteps: [MediumUploadNetworkTransport.FinishStep]
    ) -> MediumUploadFixture {
        let host = "upload-\(UUID().uuidString).example"
        let clock = MutableMediumUploadClock()
        CountingUploadURLProtocol.reset(host: host)
        let transport = MediumUploadNetworkTransport(
            uploadURL: "https://\(host)/medium-upload",
            finishSteps: finishSteps,
            clock: clock,
            startUploadTTL: 60 * 60
        )
        let client = ApolloClient(
            networkTransport: transport,
            store: ApolloStore(cache: InMemoryNormalizedCache())
        )
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CountingUploadURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let checkpointFileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("medium-upload-integration-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("checkpoints.json")
        return MediumUploadFixture(
            service: MediumUploadService(
                client: client,
                session: session,
                checkpointStore: FileMediumUploadCheckpointStore(
                    fileURL: checkpointFileURL,
                    clock: clock
                ),
                scopeProvider: FixedMediumUploadScopeProvider("integration-session"),
                clock: clock
            ),
            transport: transport,
            host: host
        )
    }

    private func imageData() throws -> Data {
        let encodedPNG = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8A" +
            "AusB9Y9JZYkAAAAASUVORK5CYII="
        return try #require(Data(base64Encoded: encodedPNG))
    }
}
