import Apollo
import ApolloAPI
import Foundation
@testable import HackersPub

actor CheckpointUploadRequestController {
    enum Behavior: Sendable {
        case succeed
        case respond(statusCode: Int)
        case suspendBeforeResponse
        case suspendAfterResponseHeaders
    }

    private var behavior: Behavior
    private var clockAdvanceOnNextRequest: (clock: MutableMediumUploadClock, interval: TimeInterval)?
    private var requestCount = 0
    private var countWaiters: [(expected: Int, continuation: CheckedContinuation<Void, Never>)] = []
    private var releaseWaiters: [CheckedContinuation<Void, Never>] = []

    init(behavior: Behavior = .succeed) {
        self.behavior = behavior
    }

    func recordRequest() -> Behavior {
        requestCount += 1
        if let advance = clockAdvanceOnNextRequest {
            clockAdvanceOnNextRequest = nil
            advance.clock.advance(by: advance.interval)
        }
        let ready = countWaiters.filter { requestCount >= $0.expected }
        countWaiters.removeAll { requestCount >= $0.expected }
        ready.forEach { $0.continuation.resume() }
        return behavior
    }

    func waitForRequestCount(_ expected: Int) async {
        guard requestCount < expected else { return }
        await withCheckedContinuation { continuation in
            countWaiters.append((expected, continuation))
        }
    }

    func suspendUntilReleased() async {
        await withCheckedContinuation { continuation in
            releaseWaiters.append(continuation)
        }
    }

    func setBehavior(_ behavior: Behavior) {
        self.behavior = behavior
    }

    func advanceClockOnNextRequest(_ clock: MutableMediumUploadClock, by interval: TimeInterval) {
        clockAdvanceOnNextRequest = (clock, interval)
    }

    func releaseAll() {
        let waiters = releaseWaiters
        releaseWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }

    func snapshotRequestCount() -> Int {
        requestCount
    }
}

class CheckpointUploadURLProtocol: URLProtocol, @unchecked Sendable {
    private static let registryLock = NSLock()
    private static var controllers: [String: CheckpointUploadRequestController] = [:]

    private let stateLock = NSLock()
    private var stopped = false

    static func register(_ controller: CheckpointUploadRequestController, for host: String) {
        registryLock.lock()
        controllers[host] = controller
        registryLock.unlock()
    }

    override class func canInit(with request: URLRequest) -> Bool {
        guard let host = request.url?.host else { return false }
        registryLock.lock()
        defer { registryLock.unlock() }
        return controllers[host] != nil
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url,
              let host = url.host,
              let controller = Self.controller(for: host)
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        Task { [weak self] in
            guard let self else { return }
            let behavior = await controller.recordRequest()
            switch behavior {
            case .succeed:
                finish(with: response(for: url, statusCode: 200))
            case let .respond(statusCode):
                finish(with: response(for: url, statusCode: statusCode))
            case .suspendBeforeResponse:
                await controller.suspendUntilReleased()
                finish(with: response(for: url, statusCode: 200))
            case .suspendAfterResponseHeaders:
                let response = response(for: url, statusCode: 200)
                deliver(response)
                await controller.suspendUntilReleased()
                finishAfterDeliveredResponse()
            }
        }
    }

    override func stopLoading() {
        stateLock.lock()
        stopped = true
        stateLock.unlock()
    }

    private static func controller(for host: String) -> CheckpointUploadRequestController? {
        registryLock.lock()
        defer { registryLock.unlock() }
        return controllers[host]
    }

    private var isStopped: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return stopped
    }

    private func response(for url: URL, statusCode: Int) -> HTTPURLResponse {
        guard let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        ) else {
            preconditionFailure("The checkpoint fixture must create a valid HTTP response")
        }
        return response
    }

    private func deliver(_ response: HTTPURLResponse) {
        guard !isStopped else { return }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    }

    private func finish(with response: HTTPURLResponse) {
        guard !isStopped else { return }
        deliver(response)
        client?.urlProtocolDidFinishLoading(self)
    }

    private func finishAfterDeliveredResponse() {
        guard !isStopped else { return }
        client?.urlProtocolDidFinishLoading(self)
    }
}

final class CheckpointUploadNetworkTransport: NetworkTransport, @unchecked Sendable {
    enum FinishStep {
        case transientFailure
        case cancellation
        case success
        case invalidInput
    }

    struct Snapshot: Equatable {
        let startRequests: Int
        let finishUploadIDs: [String]
    }

    private let lock = NSLock()
    private let uploadHost: String
    private let clock: any MediumUploadClock
    private let startUploadTTL: TimeInterval
    private var finishSteps: [FinishStep]
    private var startRequestCount = 0
    private var finishUploadIDs: [String] = []

    init(
        uploadHost: String,
        finishSteps: [FinishStep],
        clock: any MediumUploadClock,
        startUploadTTL: TimeInterval
    ) {
        self.uploadHost = uploadHost
        self.finishSteps = finishSteps
        self.clock = clock
        self.startUploadTTL = startUploadTTL
    }

    func send<Query: GraphQLQuery>(
        query _: Query,
        fetchBehavior _: FetchBehavior,
        requestConfiguration _: RequestConfiguration
    ) throws -> AsyncThrowingStream<GraphQLResponse<Query>, any Error> {
        failingStream(URLError(.unsupportedURL))
    }

    func send<Mutation: GraphQLMutation>(
        mutation: Mutation,
        requestConfiguration _: RequestConfiguration
    ) throws -> AsyncThrowingStream<GraphQLResponse<Mutation>, any Error> {
        if mutation is HackersPub.StartMediumUploadMutation {
            lock.lock()
            startRequestCount += 1
            let uploadID = "upload-\(startRequestCount)"
            lock.unlock()
            return responseStream(data: startUploadResponse(uploadID: uploadID))
        }

        if let mutation = mutation as? HackersPub.FinishMediumUploadMutation {
            lock.lock()
            finishUploadIDs.append(mutation.uploadId)
            let step = finishSteps.isEmpty ? .success : finishSteps.removeFirst()
            lock.unlock()

            switch step {
            case .transientFailure:
                return failingStream(URLError(.timedOut))
            case .cancellation:
                return failingStream(CancellationError())
            case .success:
                return responseStream(data: finishUploadResponse(uploadID: mutation.uploadId))
            case .invalidInput:
                return responseStream(data: invalidFinishResponse())
            }
        }

        return failingStream(URLError(.unsupportedURL))
    }

    func snapshot() -> Snapshot {
        lock.lock()
        defer { lock.unlock() }
        return Snapshot(startRequests: startRequestCount, finishUploadIDs: finishUploadIDs)
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

    private func startUploadResponse(uploadID: String) -> [String: Any] {
        let expiresAt = clock.now().addingTimeInterval(startUploadTTL)
        return [
            "startMediumUpload": [
                "__typename": "StartMediumUploadPayload",
                "uploadId": uploadID,
                "uploadUrl": "https://\(uploadHost)/\(uploadID)",
                "method": "PUT",
                "headers": [],
                "expires": ISO8601DateFormatter().string(from: expiresAt)
            ]
        ]
    }

    private func finishUploadResponse(uploadID: String) -> [String: Any] {
        [
            "finishMediumUpload": [
                "__typename": "FinishMediumUploadPayload",
                "medium": [
                    "__typename": "Medium",
                    "id": "Medium:medium-\(uploadID)",
                    "uuid": "medium-\(uploadID)",
                    "url": "https://hackers.pub/media/\(uploadID)",
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
}
