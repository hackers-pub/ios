@testable import HackersPub
import Testing
import UIKit

struct FeedScrollAnchorGeometryTests {
    @Test("SOC-13: global frames preserve a partially visible nested-row offset with a top inset")
    func globalFrameOffsetsRemainTheMeasurementSourceOfTruth() {
        let viewportFrame = CGRect(x: 0, y: 400, width: 320, height: 180)
        let nestedRowFrame = CGRect(x: 12, y: 377, width: 296, height: 113)
        let capturedOffset = nestedRowFrame.minY - viewportFrame.minY
        let target = FeedScrollOffsetAdjustment.targetScrollPositionY(
            metrics: FeedScrollMetrics(
                contentOffsetY: 71,
                topInset: 24,
                contentHeight: 1000,
                viewportHeight: viewportFrame.height
            ),
            currentAnchorOffset: capturedOffset,
            desiredAnchorOffset: -23
        )

        #expect(abs(capturedOffset + 23) < 0.001)
        #expect(target == 95)
    }
}
