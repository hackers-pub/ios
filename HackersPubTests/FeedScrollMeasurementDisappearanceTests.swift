@testable import HackersPub
import Testing
import UIKit

struct FeedScrollMeasurementDisappearanceTests {
    @Test("SOC-13: disappearance invalidates cached rows, viewport, and metrics before new ingress")
    @MainActor
    func disappearanceClearsCachedMeasurementsAndBlocksLateCallbacks() {
        let fixture = populatedMeasurementFixture()
        let buffer = fixture.buffer
        let owner = fixture.owner

        buffer.clearForDisappearance(layoutRevision: 7)
        let frameVersionAfterClear = buffer.frameVersion
        let metricGenerationAfterClear = buffer.metricFence.generation

        #expect(buffer.viewportFrame.isEmpty)
        #expect(buffer.rowFrames.isEmpty)
        #expect(buffer.scrollMetrics == nil)
        #expect(!buffer.isReadyForPendingRestoration)
        #expect(
            !buffer.acceptViewportFrame(
                CGRect(x: 0, y: 400, width: 320, height: 180),
                measurementEpoch: 0
            )
        )
        #expect(
            !buffer.acceptScrollMetrics(
                FeedScrollMetrics(
                    contentOffsetY: 95,
                    topInset: 24,
                    contentHeight: 1000,
                    viewportHeight: 180
                ),
                measurementEpoch: 0
            )
        )
        #expect(
            !buffer.acceptRowFrame(
                AnyHashable("post-2"),
                owner: owner,
                measurement: feedRowMeasurement(
                    frame: CGRect(x: 0, y: 377, width: 320, height: 113),
                    layoutRevision: 7
                )
            )
        )
        #expect(buffer.viewportFrame.isEmpty)
        #expect(buffer.scrollMetrics == nil)
        #expect(buffer.frameVersion == frameVersionAfterClear)
        #expect(buffer.metricFence.generation == metricGenerationAfterClear)
        #expect(!buffer.isReadyForPendingRestoration)
    }
}

private struct PopulatedMeasurementFixture {
    let buffer: FeedScrollMeasurementBuffer<String>
    let owner: UUID
}

@MainActor
private func populatedMeasurementFixture() -> PopulatedMeasurementFixture {
    let buffer = FeedScrollMeasurementBuffer<String>(layoutRevision: 7)
    let owner = UUID()
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
    return PopulatedMeasurementFixture(buffer: buffer, owner: owner)
}
