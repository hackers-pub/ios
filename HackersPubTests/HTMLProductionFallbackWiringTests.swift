import CoreGraphics
@testable import HackersPub
import SwiftUI
import Testing
import UIKit

@MainActor
struct HTMLProductionFallbackWiringTests {
    @Test
    func textRenderersUseOnlyVisibleTextWhenImporterThrows() async throws {
        let fixtures = [
            HTMLFallbackFixture(
                html: """
                <div>Visible&nbsp;&amp;&nbsp;text <strong>kept</strong>
                <!-- hidden comment -->
                <section><script>hidden <style>nested style hidden</style></script></section>
                <style>.hidden { display: none; }</style>
                <p>After &lt;safe&gt;</p></div>
                """,
                expected: "Visible & text kept After <safe>"
            ),
            HTMLFallbackFixture(html: "Before <script without close", expected: "Before"),
            HTMLFallbackFixture(html: "", expected: "")
        ]

        for (index, fixture) in fixtures.enumerated() {
            try await verifyProductionFallback(fixture, index: index)
        }
    }

    private func verifyProductionFallback(
        _ fixture: HTMLFallbackFixture,
        index: Int
    ) async throws {
        let invocationRecorder = HTMLImportInvocationRecorder()
        let importer = HTMLAttributedStringImporter { _, _, _, _ in
            invocationRecorder.count += 1
            throw ForcedHTMLImportFailure()
        }
        let uiFont = UIFont.systemFont(ofSize: 17)
        let uiColor = UIColor.label

        let staticView = HTMLTextView(
            html: fixture.html,
            attributedStringImporter: importer
        )
        let staticText = await staticView.renderedAttributedText(
            cacheKey: "fallback-static-\(index)",
            uiFont: uiFont,
            uiColor: uiColor
        ).string

        let interactive = renderInteractiveFallback(
            fixture,
            index: index,
            importer: importer,
            uiFont: uiFont,
            uiColor: uiColor
        )
        let selectable = renderSelectableFallback(
            fixture,
            index: index,
            importer: importer,
            uiFont: uiFont,
            uiColor: uiColor
        )
        defer {
            withExtendedLifetime((interactive.coordinator, selectable.coordinator)) {}
        }

        try await waitForFallback {
            interactive.label.attributedText != nil && selectable.textView.attributedText != nil
        }
        #expect(staticText == fixture.expected)
        #expect(interactive.label.attributedText?.string == fixture.expected)
        #expect(selectable.textView.attributedText?.string == fixture.expected)
        #expect(interactive.label.attributedText?.string == staticText)
        #expect(selectable.textView.attributedText?.string == staticText)
        #expect(invocationRecorder.count == 3)
    }

    private func renderInteractiveFallback(
        _ fixture: HTMLFallbackFixture,
        index: Int,
        importer: HTMLAttributedStringImporter,
        uiFont: UIFont,
        uiColor: UIColor
    ) -> (label: SelfSizingHTMLLabel, coordinator: InteractiveHTMLTextView.Coordinator) {
        var height: CGFloat = 0
        let view = InteractiveHTMLTextView(
            html: fixture.html,
            height: Binding(get: { height }, set: { height = $0 }),
            attributedStringImporter: importer
        )
        let coordinator = view.makeCoordinator()
        let label = SelfSizingHTMLLabel()
        coordinator.label = label
        coordinator.render(
            cacheKey: "fallback-interactive-\(index)",
            html: fixture.html,
            uiFont: uiFont,
            uiColor: uiColor
        )
        return (label, coordinator)
    }

    private func renderSelectableFallback(
        _ fixture: HTMLFallbackFixture,
        index: Int,
        importer: HTMLAttributedStringImporter,
        uiFont: UIFont,
        uiColor: UIColor
    ) -> (
        textView: SelfSizingSelectableHTMLTextView,
        coordinator: SelectableHTMLTextView.Coordinator
    ) {
        var height: CGFloat = 0
        let view = SelectableHTMLTextView(
            html: fixture.html,
            height: Binding(get: { height }, set: { height = $0 }),
            attributedStringImporter: importer
        )
        let coordinator = view.makeCoordinator()
        let textView = SelfSizingSelectableHTMLTextView()
        coordinator.textView = textView
        coordinator.render(
            cacheKey: "fallback-selectable-\(index)",
            html: fixture.html,
            uiFont: uiFont,
            uiColor: uiColor
        )
        return (textView, coordinator)
    }
}

private struct HTMLFallbackFixture {
    let html: String
    let expected: String
}

private struct ForcedHTMLImportFailure: Error {}

@MainActor
private final class HTMLImportInvocationRecorder {
    var count = 0
}

@MainActor
private func waitForFallback(
    attempts: Int = 200,
    _ predicate: @escaping @MainActor () -> Bool
) async throws {
    for _ in 0 ..< attempts {
        if predicate() {
            return
        }
        try await Task.sleep(for: .milliseconds(10))
    }
    throw FallbackRenderingTimeout()
}

private struct FallbackRenderingTimeout: Error {}
