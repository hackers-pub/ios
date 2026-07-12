import Foundation

enum HTMLHeightUpdatePolicy {
    static let tolerance = 0.5

    static func shouldApply(
        currentGeneration: Int,
        scheduledGeneration: Int,
        currentHeight: Double,
        measuredHeight: Double
    ) -> Bool {
        currentGeneration == scheduledGeneration
            && measuredHeight > 0
            && abs(currentHeight - measuredHeight) > tolerance
    }
}
