import AuthenticationServices

@MainActor
protocol PasskeyAuthorizationControlling: AnyObject {
    var delegate: (any ASAuthorizationControllerDelegate)? { get set }
    var presentationContextProvider: (any ASAuthorizationControllerPresentationContextProviding)? { get set }

    func performRequests()
    func cancel()
}

extension ASAuthorizationController: PasskeyAuthorizationControlling {}

protocol PasskeyRequestTimeoutClock: Sendable {
    func sleep(for duration: Duration) async throws
}

struct ContinuousPasskeyRequestTimeoutClock: PasskeyRequestTimeoutClock {
    func sleep(for duration: Duration) async throws {
        try await ContinuousClock().sleep(for: duration)
    }
}

@MainActor
protocol PasskeyAuthorizationRequestMaking {
    func makeRequest(
        request: ASAuthorizationRequest,
        presentationAnchor: ASPresentationAnchor,
        onFinish: @escaping @MainActor () -> Void
    ) -> PasskeyAuthorizationRequest
}

@MainActor
struct SystemPasskeyAuthorizationRequestFactory: PasskeyAuthorizationRequestMaking {
    static let productionTimeout: Duration = .seconds(120)

    func makeRequest(
        request: ASAuthorizationRequest,
        presentationAnchor: ASPresentationAnchor,
        onFinish: @escaping @MainActor () -> Void
    ) -> PasskeyAuthorizationRequest {
        PasskeyAuthorizationRequest(
            authorizationController: ASAuthorizationController(authorizationRequests: [request]),
            presentationAnchor: presentationAnchor,
            timeoutClock: ContinuousPasskeyRequestTimeoutClock(),
            timeout: Self.productionTimeout,
            onFinish: onFinish
        )
    }
}

@MainActor
final class PasskeyAuthorizationRequest: NSObject {
    private let presentationAnchor: ASPresentationAnchor
    private let authorizationController: any PasskeyAuthorizationControlling
    private let timeoutClock: any PasskeyRequestTimeoutClock
    private let timeout: Duration
    private let onFinish: @MainActor () -> Void
    private var completionGate = PasskeyRequestCompletionGate()
    private var continuation: CheckedContinuation<ASAuthorization, Error>?
    private var watchdogTask: Task<Void, Never>?

    init(
        authorizationController: any PasskeyAuthorizationControlling,
        presentationAnchor: ASPresentationAnchor,
        timeoutClock: any PasskeyRequestTimeoutClock,
        timeout: Duration,
        onFinish: @escaping @MainActor () -> Void
    ) {
        self.presentationAnchor = presentationAnchor
        self.authorizationController = authorizationController
        self.timeoutClock = timeoutClock
        self.timeout = timeout
        self.onFinish = onFinish
        super.init()
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
    }

    func perform() async throws -> ASAuthorization {
        try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                if Task.isCancelled {
                    self.cancel()
                } else {
                    self.startWatchdog()
                    self.authorizationController.performRequests()
                }
            }
        }, onCancel: { [self] in
            Task { @MainActor in
                self.cancel()
            }
        })
    }

    func cancel() {
        finish(.failure(PasskeyServiceError.cancelled), cancellingController: true)
    }

    private func startWatchdog() {
        let timeoutClock = timeoutClock
        let timeout = timeout
        watchdogTask = Task { [weak self] in
            do {
                try await timeoutClock.sleep(for: timeout)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            self?.finish(.failure(PasskeyServiceError.timedOut), cancellingController: true)
        }
    }

    private func finish(
        _ result: Result<ASAuthorization, Error>,
        cancellingController: Bool = false
    ) {
        guard completionGate.finish() else {
            return
        }

        if cancellingController {
            authorizationController.cancel()
        }
        watchdogTask?.cancel()
        watchdogTask = nil
        let continuation = continuation
        self.continuation = nil
        onFinish()
        continuation?.resume(with: result)
    }
}

extension PasskeyAuthorizationRequest: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(
        controller _: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        Task { @MainActor in
            finish(.success(authorization))
        }
    }

    nonisolated func authorizationController(
        controller _: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        let serviceError = (error as? ASAuthorizationError)
            .map { PasskeyAuthorizationErrorPolicy.serviceError(for: $0.code) }
            ?? .authorizationFailed
        Task { @MainActor in
            finish(.failure(serviceError))
        }
    }
}

extension PasskeyAuthorizationRequest: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for _: ASAuthorizationController) -> ASPresentationAnchor {
        presentationAnchor
    }
}
