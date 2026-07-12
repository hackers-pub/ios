@testable import HackersPub
import Testing
import UIKit

struct FontSettingsManagerFontResolutionTests {
    @Test func customFamilyUsesACloserFaceForTheRequestedWeight() throws {
        let base = try #require(UIFont(name: "Helvetica", size: 17))
        let resolved = FontSettingsManager.resolvedUIFont(
            named: base.fontName,
            size: 17,
            weight: .bold
        )

        #expect(resolved.familyName == base.familyName)
        #expect(weightDistance(for: resolved, from: .bold) < weightDistance(for: base, from: .bold))
    }

    @Test func unavailableCustomFontUsesTheRequestedSystemWeight() {
        let requestedWeight: UIFont.Weight = .semibold
        let resolved = FontSettingsManager.resolvedUIFont(
            named: "HackersPub-Not-A-Font",
            size: 17,
            weight: requestedWeight
        )

        #expect(weightDistance(for: resolved, from: requestedWeight) < 0.01)
    }

    @Test func singleFaceCustomFamilyKeepsItsSelectedFaceWhenWeightIsUnsupported() throws {
        let singleFaceName = try #require(
            UIFont.familyNames.lazy.compactMap { familyName -> String? in
                let faces = UIFont.fontNames(forFamilyName: familyName)
                return faces.count == 1 ? faces[0] : nil
            }.first
        )
        let base = try #require(UIFont(name: singleFaceName, size: 17))
        let resolved = FontSettingsManager.resolvedUIFont(
            named: base.fontName,
            size: 17,
            weight: .bold
        )

        #expect(resolved.fontName == base.fontName)
    }

    private func weightDistance(for font: UIFont, from requestedWeight: UIFont.Weight) -> CGFloat {
        abs(descriptorWeight(for: font) - requestedWeight.rawValue)
    }

    private func descriptorWeight(for font: UIFont) -> CGFloat {
        let traits = font.fontDescriptor.object(forKey: .traits) as? [UIFontDescriptor.TraitKey: Any]
        guard let number = traits?[.weight] as? NSNumber else { return 0 }
        return CGFloat(number.doubleValue)
    }
}
