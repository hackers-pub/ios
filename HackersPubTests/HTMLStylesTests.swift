@testable import HackersPub
import Testing
import UIKit

struct HTMLStylesTests {
    @Test(arguments: [
        HTMLStyles.generateCSS(fontSize: 17, fontFamily: "-apple-system"),
        HTMLStyles.generateComposePreviewCSS(fontSize: 17, fontFamily: "-apple-system")
    ])
    func contentCSSIsResponsiveAndDeclaresAdaptiveColorScheme(_ css: String) {
        #expect(css.contains("html {\n    color-scheme: light dark;"))
        #expect(css.contains("img, video {\n    max-width: 100%;\n    height: auto;"))
        #expect(css.contains("table {\n    display: block;\n    max-width: 100%;\n    overflow-x: auto;"))
        #expect(css.contains("pre {\n    max-width: 100%;"))
        #expect(css.contains("a {\n    color: light-dark(#007AFF, #0A84FF);"))
    }

    @Test
    func adaptiveLinkColorsMeetLargeTextContrastAgainstTheirModeBackgrounds() {
        let lightLink = UIColor(red: 0, green: 122 / 255, blue: 1, alpha: 1)
        let darkLink = UIColor(red: 10 / 255, green: 132 / 255, blue: 1, alpha: 1)

        #expect(contrastRatio(lightLink, .white) >= 3)
        #expect(contrastRatio(darkLink, .black) >= 3)
    }

    private func contrastRatio(_ foreground: UIColor, _ background: UIColor) -> CGFloat {
        let foregroundLuminance = relativeLuminance(foreground)
        let backgroundLuminance = relativeLuminance(background)
        return (max(foregroundLuminance, backgroundLuminance) + 0.05)
            / (min(foregroundLuminance, backgroundLuminance) + 0.05)
    }

    private func relativeLuminance(_ color: UIColor) -> CGFloat {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        #expect(color.getRed(&red, green: &green, blue: &blue, alpha: &alpha))

        func linear(_ channel: CGFloat) -> CGFloat {
            channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }
}
