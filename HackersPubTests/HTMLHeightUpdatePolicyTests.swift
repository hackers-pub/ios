@testable import HackersPub
import Testing

struct HTMLHeightUpdatePolicyTests {
    @Test(arguments: [
        (1, 1, 120.0, 121.0, true),
        (2, 1, 120.0, 121.0, false),
        (1, 1, 120.0, 120.4, false),
        (1, 1, 120.0, 0.0, false)
    ])
    func heightWritesRequireLatestGenerationAndMeaningfulDelta(
        _ currentGeneration: Int,
        _ scheduledGeneration: Int,
        _ currentHeight: Double,
        _ measuredHeight: Double,
        _ expected: Bool
    ) {
        #expect(
            HTMLHeightUpdatePolicy.shouldApply(
                currentGeneration: currentGeneration,
                scheduledGeneration: scheduledGeneration,
                currentHeight: currentHeight,
                measuredHeight: measuredHeight
            ) == expected
        )
    }
}
