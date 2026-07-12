@testable import HackersPub
import SwiftUI
import Testing

@MainActor
struct SliderHelperTests {
    @Test func nonpositiveNaNAndInfiniteStepsNeverDivideAndStillClampFiniteValues() {
        let range = 0.0 ... 1.0

        assertApproximatelyEqual(SliderHelper.snappedValue(2, step: 0, range: range), 1)
        assertApproximatelyEqual(SliderHelper.snappedValue(-1, step: -0.25, range: range), 0)
        assertApproximatelyEqual(SliderHelper.snappedValue(0.4, step: .nan, range: range), 0.4)
        assertApproximatelyEqual(SliderHelper.snappedValue(0.4, step: .infinity, range: range), 0.4)
    }

    @Test func nonfiniteInputClampsToTheNearestFiniteRangeEndpoint() {
        let range = -1.0 ... 1.0

        assertApproximatelyEqual(SliderHelper.snappedValue(.nan, step: 0.25, range: range), -1)
        assertApproximatelyEqual(SliderHelper.snappedValue(.infinity, step: 0.25, range: range), 1)
        assertApproximatelyEqual(SliderHelper.snappedValue(-.infinity, step: 0.25, range: range), -1)
    }

    @Test func bindingGetterAndSetterApplyTheSameSnappingAndClampingPolicy() {
        var storage = 1.2
        let source = Binding<Double>(
            get: { storage },
            set: { storage = $0 }
        )
        let binding = SliderHelper.snappedBinding(source, step: 0.25, range: 0 ... 1)

        assertApproximatelyEqual(binding.wrappedValue, 1)

        binding.wrappedValue = 0.62
        assertApproximatelyEqual(storage, 0.5)
        assertApproximatelyEqual(binding.wrappedValue, 0.5)

        binding.wrappedValue = -0.2
        assertApproximatelyEqual(storage, 0)
        assertApproximatelyEqual(binding.wrappedValue, 0)
    }

    @Test func fractionalNegativeAndNondivisibleBoundsRoundTripWithoutOriginBias() {
        let range = -1.0 ... 1.0

        assertApproximatelyEqual(SliderHelper.snappedValue(-0.71, step: 0.3, range: range), -0.7)
        assertApproximatelyEqual(SliderHelper.snappedValue(0.88, step: 0.3, range: range), 0.8)
        assertApproximatelyEqual(SliderHelper.snappedValue(1, step: 0.3, range: range), 1)

        var storage = -0.71
        let binding = SliderHelper.snappedBinding(
            Binding(get: { storage }, set: { storage = $0 }),
            step: 0.3,
            range: range
        )
        assertApproximatelyEqual(binding.wrappedValue, -0.7)

        binding.wrappedValue = 0.88
        assertApproximatelyEqual(storage, 0.8)
        assertApproximatelyEqual(binding.wrappedValue, 0.8)
    }

    @Test func typographySettingsUsesTheSharedSnappingBinding() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let settingsSource = try String(
            contentsOf: repositoryRoot.appending(path: "HackersPub/Views/SettingsView.swift"),
            encoding: .utf8
        )

        #expect(settingsSource.contains("SliderHelper.snappedBinding"))
    }
}

private func assertApproximatelyEqual(
    _ actual: Double,
    _ expected: Double,
    tolerance: Double = 0.000_000_1
) {
    #expect(abs(actual - expected) < tolerance)
}
