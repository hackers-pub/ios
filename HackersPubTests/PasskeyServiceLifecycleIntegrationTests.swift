import AuthenticationServices
import Foundation
@testable import HackersPub
import Testing
import UIKit

private actor ManualPasskeyTimeoutClock: PasskeyRequestTimeoutClock {
    private struct Sleeper {
        let id: UUID
        let continuation: CheckedContinuation<Void, any Error>
    }

    private var sleeper: Sleeper?
    private var armedWaiters: [CheckedContinuation<Void, Never>] = []
    private var cancellationWaiters: [(Int, CheckedContinuation<Void, Never>)] = []
    private(set) var cancellationCount = 0

    func sleep(for _: Duration) async throws {
        let id = UUID()
        try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                guard !Task.isCancelled else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                sleeper = Sleeper(id: id, continuation: continuation)
                let waiters = armedWaiters
                armedWaiters.removeAll()
                waiters.forEach { $0.resume() }
            }
        }, onCancel: {
            Task {
                await self.cancelSleeper(id: id)
            }
        })
    }

    func waitUntilArmed() async {
        guard sleeper == nil else { return }
        await withCheckedContinuation { continuation in
            armedWaiters.append(continuation)
        }
    }

    func advanceToDeadline() {
        let sleeper = sleeper
        self.sleeper = nil
        sleeper?.continuation.resume()
    }

    func waitUntilCancellationCount(_ expectedCount: Int) async {
        guard cancellationCount < expectedCount else { return }
        await withCheckedContinuation { continuation in
            cancellationWaiters.append((expectedCount, continuation))
        }
    }

    private func cancelSleeper(id: UUID) {
        guard let sleeper, sleeper.id == id else { return }
        self.sleeper = nil
        cancellationCount += 1
        sleeper.continuation.resume(throwing: CancellationError())

        let ready = cancellationWaiters.filter { $0.0 <= cancellationCount }
        cancellationWaiters.removeAll { $0.0 <= cancellationCount }
        ready.forEach { $0.1.resume() }
    }
}

@MainActor
private final class RecordingPasskeyAuthorizationController: PasskeyAuthorizationControlling {
    var delegate: (any ASAuthorizationControllerDelegate)?
    var presentationContextProvider: (any ASAuthorizationControllerPresentationContextProviding)?
    private(set) var performCount = 0
    private(set) var cancelCount = 0
    private var performWaiters: [CheckedContinuation<Void, Never>] = []
    private let callbackController: ASAuthorizationController

    init(request: ASAuthorizationRequest) {
        callbackController = ASAuthorizationController(authorizationRequests: [request])
    }

    func performRequests() {
        performCount += 1
        let waiters = performWaiters
        performWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }

    func cancel() {
        cancelCount += 1
    }

    func waitUntilPerformed() async {
        guard performCount == 0 else { return }
        await withCheckedContinuation { continuation in
            performWaiters.append(continuation)
        }
    }

    func completeWithError(_ error: any Error) async {
        delegate?.authorizationController?(
            controller: callbackController,
            didCompleteWithError: error
        )
        await Task.yield()
    }
}

@MainActor
private final class RecordingPasskeyRequestFactory: PasskeyAuthorizationRequestMaking {
    private(set) var controllers: [RecordingPasskeyAuthorizationController] = []
    private(set) var clocks: [ManualPasskeyTimeoutClock] = []
    private(set) var requests: [PasskeyAuthorizationRequest] = []
    private(set) var finishCounts: [Int] = []
    private var requestCountWaiters: [(Int, CheckedContinuation<Void, Never>)] = []

    func makeRequest(
        request: ASAuthorizationRequest,
        presentationAnchor: ASPresentationAnchor,
        onFinish: @escaping @MainActor () -> Void
    ) -> PasskeyAuthorizationRequest {
        let controller = RecordingPasskeyAuthorizationController(request: request)
        let clock = ManualPasskeyTimeoutClock()
        let index = requests.count
        finishCounts.append(0)
        let lifecycle = PasskeyAuthorizationRequest(
            authorizationController: controller,
            presentationAnchor: presentationAnchor,
            timeoutClock: clock,
            timeout: .seconds(120)
        ) { [weak self] in
            self?.finishCounts[index] += 1
            onFinish()
        }
        controllers.append(controller)
        clocks.append(clock)
        requests.append(lifecycle)

        let ready = requestCountWaiters.filter { $0.0 <= requests.count }
        requestCountWaiters.removeAll { $0.0 <= requests.count }
        ready.forEach { $0.1.resume() }
        return lifecycle
    }

    func waitUntilRequestCount(_ expectedCount: Int) async {
        guard requests.count < expectedCount else { return }
        await withCheckedContinuation { continuation in
            requestCountWaiters.append((expectedCount, continuation))
        }
    }
}

struct PasskeyServiceLifecycleIntegrationTests {
    @Test @MainActor
    func timeoutReleasesServiceSlotAndLateDelegateIsIgnored() async throws {
        let (service, factory) = try makeFixture()
        let firstTask = authorizationTask(service: service)
        await factory.waitUntilRequestCount(1)
        await factory.controllers[0].waitUntilPerformed()
        await factory.clocks[0].waitUntilArmed()

        await factory.clocks[0].advanceToDeadline()
        #expect(await serviceError(from: firstTask) == .timedOut)
        #expect(factory.controllers[0].cancelCount == 1)
        #expect(factory.finishCounts[0] == 1)

        let replacementTask = authorizationTask(service: service)
        await factory.waitUntilRequestCount(2)
        await factory.controllers[1].waitUntilPerformed()
        await factory.clocks[1].waitUntilArmed()

        await factory.controllers[0].completeWithError(NSError(domain: "late.delegate", code: 1))
        #expect(factory.finishCounts[0] == 1)
        #expect(factory.finishCounts[1] == 0)

        replacementTask.cancel()
        #expect(await serviceError(from: replacementTask) == .cancelled)
        await factory.clocks[1].waitUntilCancellationCount(1)
        #expect(factory.controllers[1].cancelCount == 1)
        #expect(factory.finishCounts[1] == 1)
    }

    @Test @MainActor
    func delegateCompletionCancelsWatchdogAndReleasesServiceSlot() async throws {
        let (service, factory) = try makeFixture()
        let firstTask = authorizationTask(service: service)
        await factory.waitUntilRequestCount(1)
        await factory.controllers[0].waitUntilPerformed()
        await factory.clocks[0].waitUntilArmed()

        await factory.controllers[0].completeWithError(NSError(domain: "authorization", code: 2))
        #expect(await serviceError(from: firstTask) == .authorizationFailed)
        await factory.clocks[0].waitUntilCancellationCount(1)
        #expect(factory.controllers[0].cancelCount == 0)
        #expect(factory.finishCounts[0] == 1)

        let secondTask = authorizationTask(service: service)
        await factory.waitUntilRequestCount(2)
        await factory.controllers[1].waitUntilPerformed()
        secondTask.cancel()
        #expect(await serviceError(from: secondTask) == .cancelled)
    }

    @MainActor
    private func makeFixture() throws -> (PasskeyService, RecordingPasskeyRequestFactory) {
        let anchor = try #require(
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first
        )
        let factory = RecordingPasskeyRequestFactory()
        let service = PasskeyService(
            presentationAnchorProvider: { anchor },
            requestFactory: factory
        )
        return (service, factory)
    }

    @MainActor
    private func authorizationTask(service: PasskeyService) -> Task<ASAuthorization, any Error> {
        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(
            relyingPartyIdentifier: "hackers.pub"
        )
        let request = provider.createCredentialAssertionRequest(challenge: Data([0x01]))
        return Task {
            try await service.authorize(request)
        }
    }

    private func serviceError(
        from task: Task<ASAuthorization, any Error>
    ) async -> PasskeyServiceError? {
        do {
            _ = try await task.value
            Issue.record("Expected passkey authorization to fail")
            return nil
        } catch let error as PasskeyServiceError {
            return error
        } catch {
            Issue.record("Unexpected passkey authorization error: \(error)")
            return nil
        }
    }
}
