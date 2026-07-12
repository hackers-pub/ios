@testable import HackersPub
import Testing
import UIKit

struct HTMLReadMoreRendererTests {
    @Test
    @MainActor
    func readMoreRetainsSemanticEmphasisAfterBodyStyling() async throws {
        let bodyColor = UIColor(red: 0.18, green: 0.42, blue: 0.27, alpha: 1)
        let html = #"<p><span style="color: red">Body text that is truncated</span></p>"#
            .htmlTruncated(
                limit: 4,
                options: HTMLTruncateOptions(readMoreText: "Read more")
            )

        let rendered = try await HTMLTextRenderer.attributedString(
            cacheKey: UUID().uuidString,
            html: html,
            uiFont: .preferredFont(forTextStyle: .body),
            uiColor: bodyColor
        )
        let renderedText = rendered.string as NSString
        let bodyRange = renderedText.range(of: "Body")
        let readMoreRange = renderedText.range(of: "Read more")

        #expect(bodyRange.location != NSNotFound)
        #expect(readMoreRange.location != NSNotFound)
        guard bodyRange.location != NSNotFound, readMoreRange.location != NSNotFound else { return }

        let renderedBodyColor = rendered.attribute(
            .foregroundColor,
            at: bodyRange.location,
            effectiveRange: nil
        ) as? UIColor
        let renderedReadMoreColor = rendered.attribute(
            .foregroundColor,
            at: readMoreRange.location,
            effectiveRange: nil
        ) as? UIColor
        let lightTraits = UITraitCollection(userInterfaceStyle: .light)
        let darkTraits = UITraitCollection(userInterfaceStyle: .dark)

        #expect(renderedBodyColor?.isEqual(bodyColor) == true)
        #expect(
            renderedReadMoreColor?.resolvedColor(with: lightTraits)
                .isEqual(UIColor.link.resolvedColor(with: lightTraits)) == true
        )
        #expect(
            renderedReadMoreColor?.resolvedColor(with: darkTraits)
                .isEqual(UIColor.link.resolvedColor(with: darkTraits)) == true
        )
        #expect(rendered.attribute(.link, at: readMoreRange.location, effectiveRange: nil) == nil)
        #expect(!rendered.string.contains(HTMLReadMoreMarker.start))
        #expect(!rendered.string.contains(HTMLReadMoreMarker.end))
    }
}

@MainActor
struct HTMLTextRendererTests {
    @Test
    func selectedFontKeepsSemanticBoldItalicAndMonospaceTraits() throws {
        let source = NSMutableAttributedString(string: "bold italic code")
        source.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: 13), range: NSRange(location: 0, length: 4))
        source.addAttribute(.font, value: UIFont.italicSystemFont(ofSize: 13), range: NSRange(location: 5, length: 6))
        source.addAttribute(
            .font,
            value: UIFont.monospacedSystemFont(ofSize: 13, weight: .regular),
            range: NSRange(location: 12, length: 4)
        )

        let selectedFont = UIFont.systemFont(ofSize: 21)
        let rendered = HTMLTextRenderer.styledAttributedString(
            from: source,
            uiFont: selectedFont,
            uiColor: .label
        )

        let bold = try #require(rendered.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)
        let italic = try #require(rendered.attribute(.font, at: 5, effectiveRange: nil) as? UIFont)
        let monospace = try #require(rendered.attribute(.font, at: 12, effectiveRange: nil) as? UIFont)

        #expect(bold.pointSize == selectedFont.pointSize)
        #expect(italic.pointSize == selectedFont.pointSize)
        #expect(monospace.pointSize == selectedFont.pointSize)
        #expect(bold.fontDescriptor.symbolicTraits.contains(.traitBold))
        #expect(italic.fontDescriptor.symbolicTraits.contains(.traitItalic))
        #expect(monospace.fontDescriptor.symbolicTraits.contains(.traitMonoSpace))
    }

    @Test
    func linksUseUIKitDynamicLinkColor() throws {
        let source = NSMutableAttributedString(string: "link")
        source.addAttribute(.link, value: "https://example.com", range: NSRange(location: 0, length: 4))

        let rendered = HTMLTextRenderer.styledAttributedString(
            from: source,
            uiFont: .systemFont(ofSize: 17),
            uiColor: .label
        )
        let linkColor = try #require(rendered.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor)

        #expect(linkColor == UIColor.link)
    }
}
