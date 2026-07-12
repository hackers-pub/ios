@testable import HackersPub
import Testing
import UIKit

struct FeedScrollMeasurementEpochTests {
    @Test("SOC-13: queued old-epoch row receive and remove callbacks cannot mutate a remounted buffer")
    @MainActor
    func queuedOldEpochCallbacksCannotMutateFreshRemountMeasurements() {
        let fixture = freshEpochMeasurementFixture()
        let buffer = fixture.buffer
        let owner = fixture.owner

        #expect(
            !buffer.acceptRowFrame(
                AnyHashable("post-2"),
                owner: owner,
                measurement: feedRowMeasurement(
                    frame: CGRect(x: 0, y: 150, width: 320, height: 113),
                    layoutRevision: 7,
                    measurementEpoch: 0,
                    appearanceGeneration: 1
                )
            )
        )
        #expect(
            !buffer.removeRowFrame(
                AnyHashable("post-2"),
                owner: owner,
                layoutRevision: 7,
                measurementEpoch: 0,
                appearanceGeneration: 1
            )
        )
        #expect(
            !buffer.acceptViewportFrame(
                CGRect(x: 0, y: 300, width: 320, height: 180),
                measurementEpoch: 0
            )
        )
        #expect(
            !buffer.acceptScrollMetrics(
                FeedScrollMetrics(
                    contentOffsetY: 203,
                    topInset: 24,
                    contentHeight: 1000,
                    viewportHeight: 180
                ),
                measurementEpoch: 0
            )
        )

        #expect(buffer.rowFrames["post-2"] == fixture.frame)
        #expect(buffer.isReadyForPendingRestoration)
    }

    @Test("SOC-13: a same-identity row appearance retires its old generation before accepting the next one")
    @MainActor
    func sameOwnerAppearanceGenerationRejectsLateReceiveAndRemove() {
        let fixture = sameOwnerAppearanceFixture()
        let buffer = fixture.buffer

        #expect(fixture.oldGeometry != fixture.newGeometry)
        #expect(
            !buffer.acceptRowFrame(
                AnyHashable("post-2"),
                owner: fixture.owner,
                measurement: feedRowMeasurement(
                    frame: fixture.oldFrame,
                    layoutRevision: 7,
                    appearanceGeneration: 1
                )
            )
        )
        #expect(
            !buffer.removeRowFrame(
                AnyHashable("post-2"),
                owner: fixture.owner,
                layoutRevision: 7,
                measurementEpoch: 0,
                appearanceGeneration: 1
            )
        )
        #expect(buffer.rowFrames["post-2"] == fixture.newFrame)
    }
}

private struct FreshEpochMeasurementFixture {
    let buffer: FeedScrollMeasurementBuffer<String>
    let owner: UUID
    let frame: CGRect
}

private struct SameOwnerAppearanceFixture {
    let buffer: FeedScrollMeasurementBuffer<String>
    let owner: UUID
    let oldFrame: CGRect
    let newFrame: CGRect
    let oldGeometry: FeedAnchorRowGeometry
    let newGeometry: FeedAnchorRowGeometry
}

@MainActor
private func sameOwnerAppearanceFixture() -> SameOwnerAppearanceFixture {
    let buffer = FeedScrollMeasurementBuffer<String>(layoutRevision: 7)
    let owner = UUID()
    let oldFrame = CGRect(x: 0, y: 180, width: 320, height: 64)
    let newFrame = CGRect(x: 0, y: 203, width: 320, height: 64)
    let oldGeometry = feedRowMeasurement(frame: newFrame, layoutRevision: 7, appearanceGeneration: 1)
    let newGeometry = feedRowMeasurement(frame: newFrame, layoutRevision: 7, appearanceGeneration: 2)
    #expect(
        buffer.acceptRowFrame(
            AnyHashable("post-2"),
            owner: owner,
            measurement: feedRowMeasurement(
                frame: oldFrame,
                layoutRevision: 7,
                appearanceGeneration: 1
            )
        )
    )
    #expect(
        buffer.removeRowFrame(
            AnyHashable("post-2"),
            owner: owner,
            layoutRevision: 7,
            measurementEpoch: 0,
            appearanceGeneration: 1
        )
    )
    #expect(
        buffer.acceptRowFrame(
            AnyHashable("post-2"),
            owner: owner,
            measurement: feedRowMeasurement(
                frame: newFrame,
                layoutRevision: 7,
                appearanceGeneration: 2
            )
        )
    )
    return SameOwnerAppearanceFixture(
        buffer: buffer,
        owner: owner,
        oldFrame: oldFrame,
        newFrame: newFrame,
        oldGeometry: oldGeometry,
        newGeometry: newGeometry
    )
}

@MainActor
private func freshEpochMeasurementFixture() -> FreshEpochMeasurementFixture {
    let buffer = FeedScrollMeasurementBuffer<String>(layoutRevision: 7)
    let owner = UUID()
    let frame = CGRect(x: 0, y: 377, width: 320, height: 113)
    buffer.clearForDisappearance(layoutRevision: 7)
    buffer.activateIngress(measurementEpoch: 1)
    #expect(
        buffer.acceptRowFrame(
            AnyHashable("post-2"),
            owner: owner,
            measurement: feedRowMeasurement(
                frame: frame,
                layoutRevision: 7,
                measurementEpoch: 1,
                appearanceGeneration: 1
            )
        )
    )
    #expect(
        buffer.acceptViewportFrame(
            CGRect(x: 0, y: 400, width: 320, height: 180),
            measurementEpoch: 1
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
            measurementEpoch: 1
        )
    )
    return FreshEpochMeasurementFixture(buffer: buffer, owner: owner, frame: frame)
}
