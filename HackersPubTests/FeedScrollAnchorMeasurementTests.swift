@testable import HackersPub
import Testing
import UIKit

struct FeedScrollAnchorMeasurementTests {
    @Test("SOC-13: a stale row teardown cannot remove a newer row instance with the same ID")
    @MainActor
    func staleRowOwnerCannotRemoveNewerMeasurement() {
        let buffer = FeedScrollMeasurementBuffer<String>(layoutRevision: 7)
        let staleOwner = UUID()
        let currentOwner = UUID()
        let staleFrame = CGRect(x: 0, y: 180, width: 320, height: 64)
        let currentFrame = CGRect(x: 0, y: 203, width: 320, height: 64)

        #expect(
            buffer.acceptRowFrame(
                AnyHashable("post-2"),
                owner: staleOwner,
                measurement: feedRowMeasurement(frame: staleFrame, layoutRevision: 7)
            )
        )
        #expect(
            buffer.acceptRowFrame(
                AnyHashable("post-2"),
                owner: currentOwner,
                measurement: feedRowMeasurement(frame: currentFrame, layoutRevision: 7)
            )
        )
        #expect(
            !buffer.acceptRowFrame(
                AnyHashable("post-2"),
                owner: staleOwner,
                measurement: feedRowMeasurement(
                    frame: CGRect(x: 0, y: 150, width: 320, height: 64),
                    layoutRevision: 7
                )
            )
        )
        #expect(
            !buffer.removeRowFrame(
                AnyHashable("post-2"),
                owner: staleOwner,
                layoutRevision: 7,
                measurementEpoch: 0,
                appearanceGeneration: 0
            )
        )
        #expect(buffer.rowFrames["post-2"] == currentFrame)
        #expect(
            buffer.removeRowFrame(
                AnyHashable("post-2"),
                owner: currentOwner,
                layoutRevision: 7,
                measurementEpoch: 0,
                appearanceGeneration: 0
            )
        )
    }

    @Test("SOC-13: a layout revision waits for current-row ingress even when its CGRect does not change")
    @MainActor
    func rowGeometryRevisionRemeasuresAnIdenticalFrameBeforeRestoring() {
        let frame = CGRect(x: 12, y: 203, width: 296, height: 64)
        let measurements = identicalFrameSemanticMeasurements(frame: frame)
        let oldMeasurement = measurements.old
        let newMeasurement = measurements.current
        let owner = UUID()
        let buffer = FeedScrollMeasurementBuffer<String>(layoutRevision: 7, measurementEpoch: 3)

        #expect(oldMeasurement.frame == newMeasurement.frame)
        #expect(oldMeasurement != newMeasurement)
        primeBufferForLayoutRevision(
            buffer,
            owner: owner,
            frame: frame,
            measurementEpoch: oldMeasurement.measurementEpoch,
            appearanceGeneration: oldMeasurement.appearanceGeneration
        )
        #expect(buffer.hasCurrentLayoutRowIngress)
        #expect(buffer.isReadyForPendingRestoration)
        buffer.prepareForLayoutRevision(8)
        buffer.activateIngress(measurementEpoch: newMeasurement.measurementEpoch)
        #expect(buffer.rowFrames.isEmpty)
        #expect(!buffer.hasCurrentLayoutRowIngress)
        #expect(!buffer.isReadyForPendingRestoration)
        acceptCurrentRevisionNonRowMeasurements(
            buffer,
            measurementEpoch: newMeasurement.measurementEpoch
        )
        #expect(!buffer.isReadyForPendingRestoration)
        #expect(
            !buffer.acceptRowFrame(
                AnyHashable("post-2"),
                owner: owner,
                measurement: oldMeasurement
            )
        )
        #expect(buffer.rowFrames.isEmpty)
        #expect(
            buffer.acceptRowFrame(
                AnyHashable("post-2"),
                owner: owner,
                measurement: newMeasurement
            )
        )
        #expect(buffer.rowFrames["post-2"] == frame)
        #expect(buffer.hasCurrentLayoutRowIngress)
        #expect(buffer.isReadyForPendingRestoration)
    }

    @Test("SOC-13: reappearance waits for row-first, viewport, and metric ingress")
    @MainActor
    func reappearanceFreshnessGateOpensOnlyAfterMetricIngress() {
        let buffer = FeedScrollMeasurementBuffer<String>(layoutRevision: 7)
        let scheduler = ManualFeedScrollCommandFrameScheduler()
        let owner = UUID()
        var metricPresenceAtReconciliation = [Bool]()
        let scheduleReconciliation = {
            scheduler.schedule { _ in
                metricPresenceAtReconciliation.append(buffer.scrollMetrics != nil)
            }
        }

        buffer.clearForDisappearance(layoutRevision: 7)
        buffer.activateIngress(measurementEpoch: 0)
        #expect(
            buffer.acceptRowFrame(
                AnyHashable("post-2"),
                owner: owner,
                measurement: feedRowMeasurement(
                    frame: CGRect(x: 0, y: 377, width: 320, height: 113),
                    layoutRevision: 7
                )
            )
        )
        #expect(buffer.acceptViewportFrame(CGRect(x: 0, y: 400, width: 320, height: 180)))
        scheduleReconciliation()
        scheduler.advanceFrame()
        scheduler.advanceFrame()

        #expect(metricPresenceAtReconciliation == [false])
        #expect(!buffer.isReadyForPendingRestoration)
        #expect(buffer.scrollMetrics == nil)

        #expect(
            buffer.acceptScrollMetrics(
                FeedScrollMetrics(
                    contentOffsetY: 95,
                    topInset: 24,
                    contentHeight: 1000,
                    viewportHeight: 180
                )
            )
        )
        scheduleReconciliation()
        scheduler.advanceFrame()
        scheduler.advanceFrame()

        #expect(metricPresenceAtReconciliation == [false, true])
        #expect(buffer.isReadyForPendingRestoration)
    }

    @Test("SOC-13: metrics-only ingress updates the metric fence without discarding current row geometry")
    @MainActor
    func metricsOnlyIngressRetainsRowsAndAdvancesFreshness() {
        let buffer = FeedScrollMeasurementBuffer<String>(layoutRevision: 7)
        let owner = UUID()
        let row = CGRect(x: 0, y: 377, width: 320, height: 113)

        #expect(
            buffer.acceptRowFrame(
                AnyHashable("post-2"),
                owner: owner,
                measurement: feedRowMeasurement(frame: row, layoutRevision: 7)
            )
        )
        #expect(buffer.acceptViewportFrame(CGRect(x: 0, y: 400, width: 320, height: 180)))
        let frameVersionBeforeMetrics = buffer.frameVersion

        #expect(
            buffer.acceptScrollMetrics(
                FeedScrollMetrics(
                    contentOffsetY: 95,
                    topInset: 24,
                    contentHeight: 1000,
                    viewportHeight: 180
                )
            )
        )

        #expect(buffer.rowFrames["post-2"] == row)
        #expect(buffer.frameVersion == frameVersionBeforeMetrics)
        #expect(buffer.metricFence.generation == 1)
    }
}

private func identicalFrameSemanticMeasurements(
    frame: CGRect
) -> (old: FeedAnchorRowGeometry, current: FeedAnchorRowGeometry) {
    (
        old: feedRowMeasurement(
            frame: frame,
            layoutRevision: 7,
            measurementEpoch: 3,
            appearanceGeneration: 11
        ),
        current: feedRowMeasurement(
            frame: frame,
            layoutRevision: 8,
            measurementEpoch: 4,
            appearanceGeneration: 12
        )
    )
}

@MainActor
private func primeBufferForLayoutRevision(
    _ buffer: FeedScrollMeasurementBuffer<String>,
    owner: UUID,
    frame: CGRect,
    measurementEpoch: Int = 0,
    appearanceGeneration: Int = 0
) {
    #expect(
        buffer.acceptRowFrame(
            AnyHashable("post-2"),
            owner: owner,
            measurement: feedRowMeasurement(
                frame: frame,
                layoutRevision: 7,
                measurementEpoch: measurementEpoch,
                appearanceGeneration: appearanceGeneration
            )
        )
    )
    #expect(
        buffer.acceptViewportFrame(
            CGRect(x: 0, y: 400, width: 320, height: 180),
            measurementEpoch: measurementEpoch
        )
    )
    #expect(
        buffer.acceptScrollMetrics(
            FeedScrollMetrics(
                contentOffsetY: 95,
                topInset: 24,
                contentHeight: 1000,
                viewportHeight: 180
            ),
            measurementEpoch: measurementEpoch
        )
    )
}

@MainActor
private func acceptCurrentRevisionNonRowMeasurements(
    _ buffer: FeedScrollMeasurementBuffer<String>,
    measurementEpoch: Int = 0
) {
    #expect(
        buffer.acceptViewportFrame(
            CGRect(x: 0, y: 401, width: 320, height: 180),
            measurementEpoch: measurementEpoch
        )
    )
    #expect(
        buffer.acceptScrollMetrics(
            FeedScrollMetrics(
                contentOffsetY: 96,
                topInset: 24,
                contentHeight: 1000,
                viewportHeight: 180
            ),
            measurementEpoch: measurementEpoch
        )
    )
}
