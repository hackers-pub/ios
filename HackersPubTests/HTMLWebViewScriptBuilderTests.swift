@testable import HackersPub
import Testing

struct HTMLWebViewScriptBuilderTests {
    @Test
    func scriptUsesSingleDocumentViewportAndRunsInitialMeasurementImmediately() {
        let source = HTMLWebViewScriptBuilder.source(
            suppressLongPressInteractions: false,
            pressToTapThresholdMs: 450,
            renderGeneration: 1
        )

        #expect(!source.contains("meta.name = 'viewport'"))
        #expect(!source.contains("DOMContentLoaded"))
        #expect(!source.contains("DOMNodeInserted"))
        #expect(source.contains("resetScrollPosition();\nreportHeightSoon();"))
    }

    @Test
    func scriptUsesMutationObserverAddedNodesToBindImageLoadAndErrorListeners() {
        let source = HTMLWebViewScriptBuilder.source(
            suppressLongPressInteractions: false,
            pressToTapThresholdMs: 450,
            renderGeneration: 1
        )

        #expect(source.contains("new MutationObserver(function(mutations)"))
        #expect(source.contains("mutation.addedNodes"))
        #expect(source.contains("bindImageHeightListeners(node);"))
        #expect(source.contains("img.addEventListener('load', reportHeightSoon, true);"))
        #expect(source.contains("img.addEventListener('error', reportHeightSoon, true);"))
    }

    @Test
    func scriptIncludesOptionalLongPressSuppressionOnlyWhenRequested() {
        let enabled = HTMLWebViewScriptBuilder.source(
            suppressLongPressInteractions: true,
            pressToTapThresholdMs: 450,
            renderGeneration: 1
        )
        let disabled = HTMLWebViewScriptBuilder.source(
            suppressLongPressInteractions: false,
            pressToTapThresholdMs: 450,
            renderGeneration: 1
        )

        #expect(enabled.contains("document.addEventListener('selectstart'"))
        #expect(!disabled.contains("document.addEventListener('selectstart'"))
    }

    @Test
    func scriptInterpolatesRuntimeValuesWithoutLeavingTemplateMarkers() {
        let source = HTMLWebViewScriptBuilder.source(
            suppressLongPressInteractions: true,
            pressToTapThresholdMs: 321,
            renderGeneration: 987
        )

        #expect(source.contains("Date.now() - pressStartTimestamp > 321"))
        #expect(!source.contains("__PRESS_TO_TAP_THRESHOLD__"))
        #expect(source.contains("generation: 987"))
        #expect(!source.contains("__RENDER_GENERATION__"))
        #expect(!source.contains("__SELECTION_SUPPRESSION__"))
    }
}
