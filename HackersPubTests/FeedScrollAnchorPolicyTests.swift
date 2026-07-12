@testable import HackersPub
import SwiftUI
import Testing

struct FeedScrollAnchorPolicyTests {
    @Test("SOC-13: a partially visible row preserves its measured viewport offset")
    func preservesMeasuredOffsetAcrossPrepend() throws {
        var policy = FeedScrollAnchorPolicy<String>()
        policy.captureBeforePrepending(
            viewport: feedViewport(
                anchors: [("post-2", -23.5), ("post-3", 89)],
                isAtTop: false
            ),
            existingIDs: ["post-1", "post-2", "post-3"]
        )

        let restorationValue = policy.takeRestoration(
            availableIDs: ["post-new", "post-1", "post-2", "post-3"]
        )
        let restoration = try #require(restorationValue)

        #expect(restoration.id == "post-2")
        #expect(restoration.offset == -23.5)
        #expect(restoration.sequence == 1)
    }

    @Test("SOC-13: a user at the top sees newly prepended rows without restoration")
    func atTopDoesNotRestoreAnOldRow() {
        var policy = FeedScrollAnchorPolicy<String>()
        policy.captureBeforePrepending(
            viewport: feedViewport(anchors: [("post-1", 0)], isAtTop: true),
            existingIDs: ["post-1", "post-2"]
        )

        let restoration = policy.takeRestoration(availableIDs: ["post-new", "post-1", "post-2"])
        #expect(restoration == nil)
    }

    @Test("SOC-13: a removed anchor falls forward to the nearest surviving row and its measured offset")
    func removedAnchorUsesDeterministicNearestFallback() throws {
        var policy = FeedScrollAnchorPolicy<String>()
        policy.captureBeforePrepending(
            viewport: feedViewport(
                anchors: [("post-2", -17), ("post-3", 96)],
                isAtTop: false
            ),
            existingIDs: ["post-1", "post-2", "post-3", "post-4"]
        )

        let restorationValue = policy.takeRestoration(
            availableIDs: ["post-new", "post-1", "post-3", "post-4"]
        )
        let restoration = try #require(restorationValue)

        #expect(restoration.id == "post-3")
        #expect(restoration.offset == 96)
    }

    @Test("SOC-13: rapid prepends supersede stale requests and reset drops pending state")
    func sequencesRapidPrependsAndResetsPendingCapture() throws {
        var policy = FeedScrollAnchorPolicy<String>()
        policy.captureBeforePrepending(
            viewport: feedViewport(anchors: [("post-2", -8)], isAtTop: false),
            existingIDs: ["post-1", "post-2"]
        )
        let firstValue = policy.takeRestoration(availableIDs: ["post-new-1", "post-1", "post-2"])
        let first = try #require(firstValue)

        policy.captureBeforePrepending(
            viewport: feedViewport(anchors: [("post-2", -8)], isAtTop: false),
            existingIDs: ["post-new-1", "post-1", "post-2"]
        )
        let secondValue = policy.takeRestoration(
            availableIDs: ["post-new-2", "post-new-1", "post-1", "post-2"]
        )
        let second = try #require(secondValue)

        #expect(second.sequence > first.sequence)
        policy.captureBeforePrepending(
            viewport: feedViewport(anchors: [("post-2", -8)], isAtTop: false),
            existingIDs: ["post-2"]
        )
        policy.reset()
        let resetRestoration = policy.takeRestoration(availableIDs: ["post-2"])
        #expect(resetRestoration == nil)
    }

    @Test("SOC-13: an interleaved newer capture supersedes an unconsumed older capture")
    func interleavedCapturesUseOnlyTheLatestViewport() throws {
        var policy = FeedScrollAnchorPolicy<String>()
        policy.captureBeforePrepending(
            viewport: feedViewport(anchors: [("post-2", -14)], isAtTop: false),
            existingIDs: ["post-1", "post-2"]
        )
        policy.captureBeforePrepending(
            viewport: feedViewport(anchors: [("post-3", 31)], isAtTop: false),
            existingIDs: ["post-new-1", "post-1", "post-2", "post-3"]
        )

        let restorationValue = policy.takeRestoration(
            availableIDs: ["post-new-2", "post-new-1", "post-1", "post-2", "post-3"]
        )
        let restoration = try #require(restorationValue)

        #expect(restoration.id == "post-3")
        #expect(restoration.offset == 31)
        let consumedRestoration = policy.takeRestoration(availableIDs: ["post-3"])
        #expect(consumedRestoration == nil)
    }

    @Test("SOC-13: one logical scroll-position delta restores the exact captured pixel offset")
    func computesSinglePixelDeltaWithoutFeedback() {
        let targetOffset = FeedScrollOffsetAdjustment.targetScrollPositionY(
            metrics: FeedScrollMetrics(
                contentOffsetY: 95,
                topInset: 0,
                contentHeight: 1000,
                viewportHeight: 180
            ),
            currentAnchorOffset: 85,
            desiredAnchorOffset: -23
        )
        let resultingAnchorOffset = 85 - (targetOffset - 95)

        #expect(targetOffset == 203)
        #expect(resultingAnchorOffset == -23)
    }

    @Test("SOC-13: logical scroll coordinates account for a nonzero top inset and clamp at content edges")
    func logicalScrollPositionAccountsForInsetsAndClamping() {
        let insetTarget = FeedScrollOffsetAdjustment.targetScrollPositionY(
            metrics: FeedScrollMetrics(
                contentOffsetY: 83,
                topInset: 12,
                contentHeight: 1000,
                viewportHeight: 180
            ),
            currentAnchorOffset: 85,
            desiredAnchorOffset: -23
        )
        let clampedTarget = FeedScrollOffsetAdjustment.targetScrollPositionY(
            metrics: FeedScrollMetrics(
                contentOffsetY: -12,
                topInset: 12,
                contentHeight: 100,
                viewportHeight: 180
            ),
            currentAnchorOffset: -40,
            desiredAnchorOffset: 0
        )

        #expect(insetTarget == 203)
        #expect(clampedTarget == 0)
    }

    @Test("SOC-13: logical scroll coordinates retain the bottom adjusted-inset range when clamped")
    func logicalScrollPositionRetainsBottomInsetRange() {
        let target = FeedScrollOffsetAdjustment.targetScrollPositionY(
            metrics: FeedScrollMetrics(
                contentOffsetY: 800,
                topInset: 24,
                bottomInset: 34,
                contentHeight: 1000,
                viewportHeight: 180
            ),
            currentAnchorOffset: 150,
            desiredAnchorOffset: 0
        )

        #expect(target == 878)
    }

    @Test("SOC-13: missing metrics do not consume a restoration and later geometry may issue it")
    func missingMetricsLeaveRestorationReplayable() {
        var tracker = FeedScrollRestorationAttemptTracker()

        #expect(tracker.mayIssue)
        #expect(tracker.attemptCount == 0)
        #expect(tracker.mayIssue)

        tracker.recordIssuedCommand()
        #expect(tracker.mayIssue)
    }

    @Test("SOC-13: delayed acknowledgement fences duplicate application and exposes a retry after three layouts")
    func delayedAcknowledgementCapsAttemptsWithVisibleRetry() {
        var tracker = FeedScrollRestorationAttemptTracker()

        tracker.recordIssuedCommand()
        tracker.recordIssuedCommand()
        #expect(!tracker.requiresVisibleRetry)
        tracker.recordIssuedCommand()

        #expect(tracker.requiresVisibleRetry)
        #expect(!tracker.mayIssue)
        tracker.reset()
        #expect(tracker.mayIssue)
    }

    @Test("SOC-13: materialization and exact-position commands have sequence-fenced identities")
    func materializationThenPositionUsesDistinctCommands() {
        let materialize = FeedScrollCommand<String>(
            sequence: 7,
            attempt: 1,
            phase: .materialize("post-2")
        )
        let position = FeedScrollCommand<String>(
            sequence: 7,
            attempt: 2,
            phase: .position(203)
        )
        let superseding = FeedScrollCommand<String>(
            sequence: 8,
            attempt: 1,
            phase: .materialize("post-3")
        )

        #expect(materialize.id != position.id)
        #expect(position.id != superseding.id)
        #expect(materialize.sequence < superseding.sequence)
    }

    @Test("SOC-13: stale preference churn cannot consume retries before fresh scroll geometry")
    func metricFenceRequiresFreshGeometryAfterEveryCommand() {
        var fence = FeedScrollMetricFence()
        fence.observeFreshMetrics()
        fence.recordIssuedCommand()

        #expect(!fence.allowsCommand)
        #expect(fence.generation == 1)
        #expect(fence.awaitingGeneration == 1)

        fence.observeFreshMetrics()
        #expect(fence.allowsCommand)
        fence.recordIssuedCommand()
        #expect(!fence.allowsCommand)
    }

    @Test("SOC-13: an unreachable clamped target exposes retry instead of consuming no-op commands")
    func clampedTargetRequiresVisibleRetry() {
        var tracker = FeedScrollRestorationAttemptTracker()
        tracker.requireVisibleRetry()

        #expect(tracker.requiresVisibleRetry)
        #expect(!tracker.mayIssue)
    }
}
