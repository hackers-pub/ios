@testable import HackersPub
import Testing

struct FeedScrollAnchorWatchdogTests {
    @Test("SOC-13: a command watchdog retries only when its exact metric token remains pending")
    func commandWatchdogIsSequenceAndMetricFenced() {
        let token = FeedScrollCommandToken(sequence: 7, attempt: 2, awaitingMetricGeneration: 4)

        #expect(
            FeedScrollWatchdog.shouldRequireRetry(
                token: token,
                pendingSequence: 7,
                attemptCount: 2,
                awaitingMetricGeneration: 4,
                scrollMetricGeneration: 4
            )
        )
        #expect(
            !FeedScrollWatchdog.shouldRequireRetry(
                token: token,
                pendingSequence: 8,
                attemptCount: 2,
                awaitingMetricGeneration: 4,
                scrollMetricGeneration: 4
            )
        )
        #expect(
            !FeedScrollWatchdog.shouldRequireRetry(
                token: token,
                pendingSequence: 7,
                attemptCount: 2,
                awaitingMetricGeneration: 5,
                scrollMetricGeneration: 4
            )
        )
        #expect(
            !FeedScrollWatchdog.shouldRequireRetry(
                token: token,
                pendingSequence: 7,
                attemptCount: 2,
                awaitingMetricGeneration: 4,
                scrollMetricGeneration: 5
            )
        )
    }

    @Test("SOC-13: a disappeared adapter invalidates watchdog mutations and can resume after fresh metrics")
    func disappearanceInvalidatesWatchdogButNotFutureMeasurement() {
        let staleToken = FeedScrollCommandToken(sequence: 7, attempt: 2, awaitingMetricGeneration: 4)
        var fence = FeedScrollMetricFence()
        fence.observeFreshMetrics()
        fence.recordIssuedCommand()
        fence.reset()

        #expect(
            !FeedScrollWatchdog.shouldRequireRetry(
                token: staleToken,
                pendingSequence: nil,
                attemptCount: 0,
                awaitingMetricGeneration: fence.awaitingGeneration,
                scrollMetricGeneration: fence.generation
            )
        )
        #expect(fence.allowsCommand)
        fence.observeFreshMetrics()
        #expect(fence.allowsCommand)
    }
}
