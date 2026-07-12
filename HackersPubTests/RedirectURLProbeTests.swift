import Foundation
@testable import HackersPub
import Testing

private final class RedirectProbeProtocolState: @unchecked Sendable {
    enum Mode {
        case cancelDuringHead
        case cancelDuringGet
        case fallback
        case headerThenDeferredBody
        case timeout
    }

    enum Event: Equatable {
        case started(String)
        case stopped(String)
        case bodyAttempted(delivered: Bool)
    }

    enum Action {
        case wait
        case header(statusCode: Int, deferredBody: Bool)
    }

    private let mode: Mode
    private let lock = NSLock()
    private var recordedRequests: [URLRequest] = []
    private var stoppedProtocolIDs: Set<ObjectIdentifier> = []
    private var stoppedMethods: [String] = []
    private var deferredBodies: [() -> Void] = []
    private let eventContinuation: AsyncStream<Event>.Continuation
    let events: AsyncStream<Event>

    init(mode: Mode) {
        self.mode = mode
        let stream = AsyncStream.makeStream(of: Event.self)
        events = stream.stream
        eventContinuation = stream.continuation
    }

    var requests: [URLRequest] {
        lock.withLock { recordedRequests }
    }

    func action(for request: URLRequest) -> Action {
        let method = request.httpMethod ?? ""
        let action = lock.withLock { () -> Action in
            recordedRequests.append(request)
            switch mode {
            case .cancelDuringHead, .timeout:
                return .wait
            case .cancelDuringGet:
                return method == "HEAD"
                    ? .header(statusCode: 405, deferredBody: false)
                    : .wait
            case .fallback:
                return method == "HEAD"
                    ? .header(statusCode: 405, deferredBody: false)
                    : .header(statusCode: 200, deferredBody: false)
            case .headerThenDeferredBody:
                return method == "HEAD"
                    ? .header(statusCode: 405, deferredBody: false)
                    : .header(statusCode: 200, deferredBody: true)
            }
        }
        eventContinuation.yield(.started(method))
        return action
    }

    func recordStop(protocolID: ObjectIdentifier, method: String) {
        lock.withLock {
            stoppedProtocolIDs.insert(protocolID)
            stoppedMethods.append(method)
        }
        eventContinuation.yield(.stopped(method))
    }

    func isStopped(protocolID: ObjectIdentifier) -> Bool {
        lock.withLock { stoppedProtocolIDs.contains(protocolID) }
    }

    func stopCount(for method: String) -> Int {
        lock.withLock { stoppedMethods.count { $0 == method } }
    }

    func registerDeferredBody(_ body: @escaping () -> Void) {
        lock.withLock {
            deferredBodies.append(body)
        }
    }

    func releaseDeferredBodies() {
        let bodies = lock.withLock { () -> [() -> Void] in
            defer { deferredBodies.removeAll() }
            return deferredBodies
        }
        bodies.forEach { $0() }
    }

    func recordBodyAttempt(delivered: Bool) {
        eventContinuation.yield(.bodyAttempted(delivered: delivered))
    }

    func waitUntilStarted(_ method: String) async {
        for await event in events where event == .started(method) {
            return
        }
    }

    func waitUntilStopped(_ method: String) async {
        for await event in events where event == .stopped(method) {
            return
        }
    }

    func awaitStop(
        _ method: String,
        timeoutNanoseconds: UInt64 = 1_000_000_000
    ) async -> Bool {
        guard stopCount(for: method) == 0 else { return true }

        return await withTaskGroup(of: Bool.self) { group in
            group.addTask { [events] in
                for await event in events where event == .stopped(method) {
                    return true
                }
                return false
            }
            group.addTask {
                do {
                    try await Task.sleep(nanoseconds: timeoutNanoseconds)
                    return false
                } catch {
                    return false
                }
            }

            let didStop = await group.next() ?? false
            group.cancelAll()
            return didStop
        }
    }

    func waitForBodyAttempt() async -> Bool {
        for await event in events {
            if case let .bodyAttempted(delivered) = event {
                return delivered
            }
        }
        return false
    }
}

private final class RedirectProbeURLProtocol: URLProtocol, @unchecked Sendable {
    static var state: RedirectProbeProtocolState?
    private var requestState: RedirectProbeProtocolState?

    override static func canInit(with _: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let state = Self.state else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        requestState = state
        let protocolID = ObjectIdentifier(self)
        let action = state.action(for: request)

        switch action {
        case .wait:
            return
        case let .header(statusCode, deferredBody):
            DispatchQueue.global().async { [self] in
                guard let requestURL = request.url else {
                    client?.urlProtocol(self, didFailWithError: URLError(.badURL))
                    return
                }
                guard let response = HTTPURLResponse(
                    url: requestURL,
                    statusCode: statusCode,
                    httpVersion: "HTTP/1.1",
                    headerFields: ["Content-Length": "4"]
                ) else {
                    client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
                    return
                }
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)

                if deferredBody {
                    state.registerDeferredBody { [weak self, state] in
                        guard let self else {
                            state.recordBodyAttempt(delivered: false)
                            return
                        }
                        let delivered = !state.isStopped(protocolID: protocolID)
                        if delivered {
                            client?.urlProtocol(self, didLoad: Data("body".utf8))
                        }
                        state.recordBodyAttempt(delivered: delivered)
                    }
                }
                client?.urlProtocolDidFinishLoading(self)
            }
        }
    }

    override func stopLoading() {
        requestState?.recordStop(
            protocolID: ObjectIdentifier(self),
            method: request.httpMethod ?? ""
        )
    }
}

@Suite(.serialized)
struct RedirectURLProbeTests {
    @Test func usesBoundedHeadAndRangedGetFallbackRequests() throws {
        let url = try #require(URL(string: "https://hackers.pub/@alice/123"))
        let head = RedirectProbeRequest.make(url: url, method: .head)
        let fallback = RedirectProbeRequest.make(url: url, method: .rangedGet)

        #expect(head.httpMethod == "HEAD")
        #expect(head.timeoutInterval <= 5)
        #expect(head.value(forHTTPHeaderField: "Range") == nil)
        #expect(fallback.httpMethod == "GET")
        #expect(fallback.timeoutInterval <= 5)
        #expect(fallback.value(forHTTPHeaderField: "Range") == "bytes=0-0")
    }

    @Test func cancellationDuringHeadNeverStartsFallbackGet() async throws {
        let url = try #require(URL(string: "https://hackers.pub/@alice/123"))
        let state = RedirectProbeProtocolState(mode: .cancelDuringHead)
        let probe = makeProbe(state: state)
        let task = Task {
            try await probe.redirectedURL(from: url)
        }

        await state.waitUntilStarted("HEAD")
        task.cancel()

        do {
            _ = try await task.value
            Issue.record("Expected cancellation")
        } catch {
            #expect(error is CancellationError)
        }
        await state.waitUntilStopped("HEAD")

        #expect(state.requests.filter { $0.httpMethod == "GET" }.isEmpty)
    }

    @Test func cancellationDuringFallbackGetCancelsItsURLSessionTask() async throws {
        let url = try #require(URL(string: "https://hackers.pub/@alice/123"))
        let state = RedirectProbeProtocolState(mode: .cancelDuringGet)
        let probe = makeProbe(state: state)
        let task = Task {
            try await probe.redirectedURL(from: url)
        }

        await state.waitUntilStarted("GET")
        task.cancel()

        do {
            _ = try await task.value
            Issue.record("Expected cancellation")
        } catch {
            #expect(error is CancellationError)
        }
        await state.waitUntilStopped("GET")

        #expect(state.stopCount(for: "GET") == 1)
    }

    @Test func headMethodNotAllowedFallsBackToRangedGet() async throws {
        let url = try #require(URL(string: "https://hackers.pub/@alice/123"))
        let state = RedirectProbeProtocolState(mode: .fallback)
        let probe = makeProbe(state: state)

        let redirectedURL = try await probe.redirectedURL(from: url)
        let requests = state.requests
        let fallback = try #require(requests.first { $0.httpMethod == "GET" })

        #expect(redirectedURL == url)
        #expect(requests.map(\.httpMethod) == ["HEAD", "GET"])
        #expect(fallback.value(forHTTPHeaderField: "Range") == "bytes=0-0")
    }

    @Test func fallbackStopsAfterHeadersBeforeDeferredBodyDelivery() async throws {
        let url = try #require(URL(string: "https://hackers.pub/@alice/123"))
        let state = RedirectProbeProtocolState(mode: .headerThenDeferredBody)
        let probe = makeProbe(state: state)

        let redirectedURL = try await probe.redirectedURL(from: url)
        let didStop = await state.awaitStop("GET")
        state.releaseDeferredBodies()
        let bodyWasDelivered = await state.waitForBodyAttempt()

        #expect(redirectedURL == url)
        #expect(didStop)
        #expect(state.stopCount(for: "GET") == 1)
        #expect(!bodyWasDelivered)
    }

    @Test func eachRedirectPhaseUsesItsDeterministicTimeout() async throws {
        let url = try #require(URL(string: "https://hackers.pub/@alice/123"))
        let state = RedirectProbeProtocolState(mode: .timeout)
        let probe = makeProbe(state: state, timeoutInterval: 0.02)
        let clock = ContinuousClock()
        let startedAt = clock.now

        let redirectedURL = try await probe.redirectedURL(from: url)
        let elapsed = startedAt.duration(to: clock.now)

        #expect(redirectedURL == nil)
        #expect(state.requests.map(\.httpMethod) == ["HEAD", "GET"])
        #expect(elapsed < .seconds(1))
    }

    private func makeProbe(
        state: RedirectProbeProtocolState,
        timeoutInterval: TimeInterval = 0.5
    ) -> RedirectURLProbe {
        RedirectProbeURLProtocol.state = state
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RedirectProbeURLProtocol.self]
        return RedirectURLProbe(
            configuration: configuration,
            timeoutInterval: timeoutInterval
        )
    }
}
