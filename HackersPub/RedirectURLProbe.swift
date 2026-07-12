import Foundation

enum RedirectProbeRequest {
    enum Method {
        case head
        case rangedGet
    }

    static let defaultTimeout: TimeInterval = 5

    static func make(
        url: URL,
        method: Method,
        timeoutInterval: TimeInterval = defaultTimeout
    ) -> URLRequest {
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.timeoutInterval = timeoutInterval

        switch method {
        case .head:
            request.httpMethod = "HEAD"
        case .rangedGet:
            request.httpMethod = "GET"
            request.setValue("bytes=0-0", forHTTPHeaderField: "Range")
        }

        return request
    }
}

private struct RedirectProbeCompletion {
    let continuation: CheckedContinuation<HTTPURLResponse, Error>
    let result: Result<HTTPURLResponse, Error>
    let dataTask: URLSessionDataTask?
    let session: URLSession?
    let timeoutTask: Task<Void, Never>?
}

private final class RedirectHeaderResponseProbe: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let configuration: URLSessionConfiguration
    private let lock = NSLock()
    private var continuation: CheckedContinuation<HTTPURLResponse, Error>?
    private var receivedResponse: HTTPURLResponse?
    private var session: URLSession?
    private var dataTask: URLSessionDataTask?
    private var timeoutTask: Task<Void, Never>?
    private var wasCancelledByParent = false
    private var didTimeOut = false
    private var didComplete = false

    init(configuration: URLSessionConfiguration) {
        self.configuration = configuration
    }

    func response(for request: URLRequest) async throws -> HTTPURLResponse {
        try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                start(request: request, continuation: continuation)
            }
        } onCancel: { [weak self] in
            self?.cancelFromParentTask()
        }
    }

    private func start(
        request: URLRequest,
        continuation: CheckedContinuation<HTTPURLResponse, Error>
    ) {
        let session = URLSession(
            configuration: configuration,
            delegate: self,
            delegateQueue: nil
        )
        let dataTask = session.dataTask(with: request)
        let shouldStart = lock.withLock { () -> Bool in
            guard !wasCancelledByParent else { return false }
            self.continuation = continuation
            self.session = session
            self.dataTask = dataTask
            return true
        }

        guard shouldStart else {
            session.invalidateAndCancel()
            continuation.resume(throwing: CancellationError())
            return
        }

        dataTask.resume()
        scheduleTimeout(after: request.timeoutInterval)
    }

    private func scheduleTimeout(after timeoutInterval: TimeInterval) {
        let nanoseconds = UInt64(max(0, timeoutInterval) * 1_000_000_000)
        let task = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: nanoseconds)
            } catch {
                return
            }
            self?.timeOut()
        }
        let shouldKeepTask = lock.withLock { () -> Bool in
            guard !didComplete else { return false }
            timeoutTask = task
            return true
        }
        if !shouldKeepTask {
            task.cancel()
        }
    }

    private func cancelFromParentTask() {
        let shouldFinish = lock.withLock { () -> Bool in
            wasCancelledByParent = true
            return continuation != nil && !didComplete
        }
        if shouldFinish {
            finish(error: CancellationError())
        }
    }

    private func timeOut() {
        let shouldFinish = lock.withLock { () -> Bool in
            didTimeOut = true
            return continuation != nil && !didComplete
        }
        if shouldFinish {
            finish(error: URLError(.timedOut))
        }
    }

    private func finish(error: Error?) {
        let completion = lock.withLock { () -> RedirectProbeCompletion? in
            guard !didComplete, let continuation else { return nil }
            didComplete = true

            let result: Result<HTTPURLResponse, Error>
            if wasCancelledByParent {
                result = .failure(CancellationError())
            } else if didTimeOut {
                result = .failure(URLError(.timedOut))
            } else if let receivedResponse {
                result = .success(receivedResponse)
            } else {
                result = .failure(error ?? URLError(.badServerResponse))
            }

            let completion = RedirectProbeCompletion(
                continuation: continuation,
                result: result,
                dataTask: dataTask,
                session: session,
                timeoutTask: timeoutTask
            )
            self.continuation = nil
            self.receivedResponse = nil
            self.dataTask = nil
            self.session = nil
            self.timeoutTask = nil
            return completion
        }

        guard let completion else { return }
        completion.timeoutTask?.cancel()
        completion.dataTask?.cancel()
        completion.session?.invalidateAndCancel()

        switch completion.result {
        case let .success(response):
            completion.continuation.resume(returning: response)
        case let .failure(error):
            completion.continuation.resume(throwing: error)
        }
    }

    func urlSession(
        _: URLSession,
        dataTask _: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        lock.withLock {
            guard !didComplete else { return }
            receivedResponse = response as? HTTPURLResponse
        }
        completionHandler(.cancel)
        finish(error: nil)
    }

    func urlSession(
        _: URLSession,
        task _: URLSessionTask,
        didCompleteWithError error: (any Error)?
    ) {
        finish(error: error)
    }
}

final class RedirectURLProbe: @unchecked Sendable {
    private let configuration: URLSessionConfiguration
    private let timeoutInterval: TimeInterval

    init(
        configuration: URLSessionConfiguration = .ephemeral,
        timeoutInterval: TimeInterval = RedirectProbeRequest.defaultTimeout
    ) {
        guard let copiedConfiguration = configuration.copy() as? URLSessionConfiguration else {
            preconditionFailure("URLSessionConfiguration must support copying")
        }
        copiedConfiguration.timeoutIntervalForRequest = timeoutInterval
        self.configuration = copiedConfiguration
        self.timeoutInterval = timeoutInterval
    }

    func redirectedURL(from url: URL) async throws -> URL? {
        try Task.checkCancellation()
        let headRequest = RedirectProbeRequest.make(
            url: url,
            method: .head,
            timeoutInterval: timeoutInterval
        )
        if let headResponse = try await responseIfAvailable(for: headRequest) {
            if (200 ..< 400).contains(headResponse.statusCode) {
                try Task.checkCancellation()
                return headResponse.url
            }
        }

        try Task.checkCancellation()
        let fallbackRequest = RedirectProbeRequest.make(
            url: url,
            method: .rangedGet,
            timeoutInterval: timeoutInterval
        )
        guard let fallbackResponse = try await responseIfAvailable(for: fallbackRequest),
              (200 ..< 400).contains(fallbackResponse.statusCode)
        else {
            try Task.checkCancellation()
            return nil
        }

        try Task.checkCancellation()
        return fallbackResponse.url
    }

    private func responseIfAvailable(for request: URLRequest) async throws -> HTTPURLResponse? {
        do {
            return try await RedirectHeaderResponseProbe(configuration: configuration)
                .response(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            try Task.checkCancellation()
            return nil
        }
    }
}
