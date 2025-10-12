import Foundation
import SwiftUI

struct SliderHelper {
    // NOTE: iOS 26 has bug which Slider step value is ignored.
    // This is workaround for iOS 26 to rounding double values.
    static func snappedBinding(
        _ value: Binding<Double>,
        step: Double,
        range: ClosedRange<Double>
    ) -> Binding<Double> {
        Binding(
            get: { value.wrappedValue },
            set: { newValue in
                var snapped = (newValue / step).rounded() * step
                snapped = min(max(snapped, range.lowerBound), range.upperBound)

                if abs(snapped.rounded() - snapped) < 1e-9 {
                    snapped = snapped.rounded()
                }
                value.wrappedValue = snapped
            }
        )
    }
}
