import CoreGraphics
@testable import HackersPub
import Testing

struct HTMLContentReloadStateTests {
    @Test
    func changedHTMLImmediatelyHidesThePreviousMeasurementAndShowsLoading() {
        var state = HTMLContentReloadState()
        state.beginRendering(html: "<p>old</p>")
        state.applyMeasuredHeight(88, for: "<p>old</p>")

        state.beginRendering(html: "<p>new</p>")

        #expect(state.height(for: "<p>new</p>") == 0)
        #expect(state.isLoading(for: "<p>new</p>"))
    }

    @Test
    func lateMeasurementForReplacedHTMLCannotOverwriteTheNewContent() {
        var state = HTMLContentReloadState()
        state.beginRendering(html: "<p>old</p>")
        state.beginRendering(html: "<p>new</p>")

        state.applyMeasuredHeight(88, for: "<p>old</p>")

        #expect(state.height(for: "<p>new</p>") == 0)
        #expect(state.isLoading(for: "<p>new</p>"))
    }

    @Test
    func sameHTMLIdentityKeepsItsCurrentMeasurement() {
        var state = HTMLContentReloadState()
        state.beginRendering(html: "<p>cached</p>")
        state.applyMeasuredHeight(120, for: "<p>cached</p>")

        state.beginRendering(html: "<p>cached</p>")

        #expect(state.height(for: "<p>cached</p>") == 120)
        #expect(!state.isLoading(for: "<p>cached</p>"))
    }
}
