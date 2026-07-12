import CoreGraphics
import Foundation
@testable import HackersPub
import SwiftUI
import Testing

@MainActor
struct HTMLWebRenderGenerationTests {
    @Test
    func coordinatorRejectsOldNavigationAndHeightMessagesForSameContentKey() {
        var measuredHeight: CGFloat = 0
        let parent = HTMLWebView(
            html: "<p>same content</p>",
            height: Binding(
                get: { measuredHeight },
                set: { measuredHeight = $0 }
            )
        )
        let coordinator = parent.makeCoordinator()
        let key = HTMLContentKey(
            measurementVersion: 7,
            html: "<p>same content \(UUID().uuidString)</p>",
            fontName: "System",
            sizeMultiplier: 1,
            useSystemDynamicType: true,
            dynamicTypeSize: .large,
            availableWidth: 320
        )
        let oldNavigation = NSObject()
        let currentNavigation = NSObject()

        let oldRender = coordinator.beginRender(for: key)
        coordinator.bindNavigationIdentity(oldNavigation, to: oldRender)
        let currentRender = coordinator.beginRender(for: key)
        coordinator.bindNavigationIdentity(currentNavigation, to: currentRender)

        #expect(coordinator.renderToken(forFinishedNavigationIdentity: oldNavigation) == nil)
        #expect(coordinator.renderToken(forFinishedNavigationIdentity: currentNavigation) == currentRender)

        let oldHeightMessage: [String: Any] = ["generation": oldRender.generation, "height": 111]
        #expect(!coordinator.processHeightMessageBody(oldHeightMessage))
        #expect(measuredHeight == 0)

        let currentHeightMessage: [String: Any] = ["generation": currentRender.generation, "height": 222]
        #expect(coordinator.processHeightMessageBody(currentHeightMessage))
        #expect(measuredHeight == 222)
        #expect(HTMLHeightCache.shared.height(for: key) == 222)

        coordinator.detach()

        let detachedHeightMessage: [String: Any] = ["generation": currentRender.generation, "height": 333]
        #expect(!coordinator.processHeightMessageBody(detachedHeightMessage))
        #expect(measuredHeight == 222)
    }

    @Test
    func measurementScriptCarriesTheExplicitRenderGeneration() {
        let source = HTMLWebViewScriptBuilder.source(
            suppressLongPressInteractions: false,
            pressToTapThresholdMs: 450,
            renderGeneration: 42
        )

        #expect(source.contains("generation: 42"))
        #expect(source.contains("height: computedDocumentHeight()"))
        #expect(!source.contains("__RENDER_GENERATION__"))
    }
}
