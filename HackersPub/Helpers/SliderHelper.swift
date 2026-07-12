import Foundation
import SwiftUI

enum SliderHelper {
    /// NOTE: iOS 26 has bug which Slider step value is ignored.
    /// This is workaround for iOS 26 to rounding double values.
    static func snappedValue(
        _ value: Double,
        step: Double,
        range: ClosedRange<Double>
    ) -> Double {
        let clampedValue = clampedFiniteValue(value, to: range)
        guard step.isFinite, step > 0 else {
            return normalized(clampedValue)
        }

        let stepOffset = (clampedValue - range.lowerBound) / step
        guard stepOffset.isFinite else {
            return normalized(clampedValue)
        }

        let snappedValue = range.lowerBound + stepOffset.rounded() * step
        return normalized(clampedFiniteValue(snappedValue, to: range))
    }

    static func snappedBinding(
        _ value: Binding<Double>,
        step: Double,
        range: ClosedRange<Double>
    ) -> Binding<Double> {
        Binding(
            get: {
                snappedValue(value.wrappedValue, step: step, range: range)
            },
            set: { newValue in
                value.wrappedValue = snappedValue(newValue, step: step, range: range)
            }
        )
    }

    private static func clampedFiniteValue(
        _ value: Double,
        to range: ClosedRange<Double>
    ) -> Double {
        if value.isNaN || value == -.infinity {
            return range.lowerBound
        }
        if value == .infinity {
            return range.upperBound
        }
        return min(max(value, range.lowerBound), range.upperBound)
    }

    private static func normalized(_ value: Double) -> Double {
        let nearestInteger = value.rounded()
        return abs(nearestInteger - value) < 1e-9 ? nearestInteger : value
    }
}
