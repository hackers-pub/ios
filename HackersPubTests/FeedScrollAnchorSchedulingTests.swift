import CoreFoundation
@testable import HackersPub
import Testing

struct FeedScrollAnchorSchedulingTests {
    @Test("SOC-13: command execution requires its bound restoration, layout, frame, and metric generations")
    func staleCommandsRecomputeWithoutReplacingNewerCommands() {
        let command = FeedScrollCommand<String>(sequence: 7, attempt: 1, phase: .position(203))
        let currentContext = feedFreshnessContext(
            restorationSequence: 7,
            pendingRestorationSequence: 7,
            layoutRevision: 7,
            frameVersion: 11,
            scrollMetricGeneration: 4
        )
        let token = FeedScrollCommandExecutionToken(command: command, context: currentContext)
        let newer = FeedScrollCommand<String>(sequence: 8, attempt: 1, phase: .materialize("post-3"))

        #expect(FeedScrollCommandFreshness.isCurrent(token, context: currentContext))
        for staleContext in staleCommandFreshnessContexts() {
            #expect(!FeedScrollCommandFreshness.isCurrent(token, context: staleContext))
        }
        #expect(newer.sequence > token.command.sequence)
    }

    @Test("SOC-13: sequence-zero initial-anchor work is bound to its pristine layout context")
    func initialAnchorCommandRequiresPristineFreshnessContext() {
        let initialContext = feedFreshnessContext(
            restorationSequence: nil,
            pendingRestorationSequence: nil,
            layoutRevision: 0,
            frameVersion: 11,
            scrollMetricGeneration: 4
        )
        let token = FeedScrollCommandExecutionToken(
            command: FeedScrollCommand<String>(sequence: 0, attempt: 1, phase: .position(203)),
            context: initialContext
        )

        #expect(FeedScrollCommandFreshness.isCurrent(token, context: initialContext))
        #expect(
            !FeedScrollCommandFreshness.isCurrent(
                token,
                context: feedFreshnessContext(
                    restorationSequence: nil,
                    pendingRestorationSequence: nil,
                    layoutRevision: 0,
                    frameVersion: 12,
                    scrollMetricGeneration: 4
                )
            )
        )
        #expect(
            !FeedScrollCommandFreshness.isCurrent(
                token,
                context: feedFreshnessContext(
                    restorationSequence: 7,
                    pendingRestorationSequence: 7,
                    layoutRevision: 7,
                    frameVersion: 11,
                    scrollMetricGeneration: 4
                )
            )
        )
    }

    @Test("SOC-13: layout revision follows the bound restoration sequence without an adapter state write")
    func layoutRevisionFollowsBoundRestoration() {
        let older = FeedScrollAnchorPolicy<String>.Restoration(
            id: "post-2",
            offset: -23,
            sequence: 7
        )
        let newer = FeedScrollAnchorPolicy<String>.Restoration(
            id: "post-3",
            offset: -11,
            sequence: 8
        )

        #expect(FeedScrollAnchorLayoutRevision.value(for: nil as FeedScrollAnchorPolicy<String>.Restoration?) == 0)
        #expect(FeedScrollAnchorLayoutRevision.value(for: older) == 7)
        #expect(FeedScrollAnchorLayoutRevision.value(for: newer) == 8)
    }

    @Test("SOC-13: measurement reconciliation accepts only its exact layout, frame, and metric token")
    func measurementReconciliationRequiresFreshToken() {
        let currentContext = feedFreshnessContext(
            restorationSequence: 7,
            pendingRestorationSequence: 7,
            layoutRevision: 7,
            frameVersion: 11,
            scrollMetricGeneration: 4
        )
        let token = FeedScrollMeasurementToken(context: currentContext)

        #expect(FeedScrollMeasurementFreshness.isCurrent(token, context: currentContext))
        for staleContext in staleMeasurementFreshnessContexts() {
            #expect(!FeedScrollMeasurementFreshness.isCurrent(token, context: staleContext))
        }
    }

    @Test("SOC-13: a manual display scheduler requires a physical-frame boundary and cancels stale work")
    @MainActor
    func manualSchedulerArmsBeforeExecutingAndCancels() {
        let scheduler = ManualFeedScrollCommandFrameScheduler()
        var executedFrames = [Int]()

        scheduler.schedule { frame in
            executedFrames.append(frame.generation)
        }
        scheduler.advanceFrame()
        #expect(executedFrames.isEmpty)
        scheduler.advanceFrame()
        #expect(executedFrames == [2])

        scheduler.schedule { frame in
            executedFrames.append(frame.generation)
        }
        scheduler.cancel()
        scheduler.advanceFrame()
        scheduler.advanceFrame()
        #expect(executedFrames == [2])
    }

    @Test("SOC-13: replacing pending reconciliation does not reset its physical arm")
    @MainActor
    func manualSchedulerReplacementKeepsTheFirstEligibleFrame() {
        let scheduler = ManualFeedScrollCommandFrameScheduler()
        var executedTokens = [Int]()

        scheduler.schedule { _ in
            executedTokens.append(1)
        }
        scheduler.advanceFrame()
        scheduler.schedule { _ in
            executedTokens.append(2)
        }
        scheduler.advanceFrame()

        #expect(executedTokens == [2])
    }

    @Test("SOC-13: continuous reconciliation updates execute the latest token at each armed boundary")
    @MainActor
    func manualSchedulerDoesNotStarveWhenReplacingPendingReconciliation() {
        let scheduler = ManualFeedScrollCommandFrameScheduler()
        var executedTokens = [Int]()

        for token in 1 ... 8 {
            scheduler.schedule { _ in
                executedTokens.append(token)
            }
            scheduler.advanceFrame()
        }

        #expect(executedTokens == [2, 4, 6, 8])
    }

    @Test("SOC-13: the production scheduler preserves its arm on replacement and cancels stale work")
    @MainActor
    func productionSchedulerPreservesArmOnReplacementAndCancels() async {
        let scheduler = FeedScrollCommandDisplayLinkScheduler()
        defer { scheduler.cancel() }
        var executedTokens = [String]()

        scheduler.schedule { frame in
            executedTokens.append("1-\(frame.generation)")
        }
        await awaitNextDisplayFrame()
        #expect(executedTokens.isEmpty)
        scheduler.schedule { frame in
            executedTokens.append("2-\(frame.generation)")
        }
        await awaitNextDisplayFrame()

        #expect(executedTokens == ["2-2"])
        scheduler.schedule { frame in
            executedTokens.append("3-\(frame.generation)")
        }
        scheduler.cancel()
        await awaitNextDisplayFrame()
        await awaitNextDisplayFrame()

        #expect(executedTokens == ["2-2"])
    }
}

private func staleCommandFreshnessContexts() -> [FeedScrollFreshnessContext] {
    var contexts = [FeedScrollFreshnessContext]()
    contexts.append(
        feedFreshnessContext(
            restorationSequence: 8,
            pendingRestorationSequence: 7,
            layoutRevision: 8,
            frameVersion: 11,
            scrollMetricGeneration: 4
        )
    )
    contexts.append(
        feedFreshnessContext(
            restorationSequence: 7,
            pendingRestorationSequence: 7,
            layoutRevision: 7,
            frameVersion: 12,
            scrollMetricGeneration: 4
        )
    )
    contexts.append(
        feedFreshnessContext(
            restorationSequence: 7,
            pendingRestorationSequence: 7,
            layoutRevision: 7,
            frameVersion: 11,
            scrollMetricGeneration: 5
        )
    )
    return contexts
}

private func staleMeasurementFreshnessContexts() -> [FeedScrollFreshnessContext] {
    var contexts = staleCommandFreshnessContexts()
    contexts[0] = feedFreshnessContext(
        restorationSequence: 8,
        pendingRestorationSequence: 8,
        layoutRevision: 8,
        frameVersion: 11,
        scrollMetricGeneration: 4
    )
    contexts.append(
        feedFreshnessContext(
            restorationSequence: 7,
            pendingRestorationSequence: nil,
            layoutRevision: 7,
            frameVersion: 11,
            scrollMetricGeneration: 4
        )
    )
    return contexts
}
