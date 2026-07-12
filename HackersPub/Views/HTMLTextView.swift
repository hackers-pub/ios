import SwiftUI
import UIKit

@MainActor
final class HTMLAttributedStringCache {
    static let shared = HTMLAttributedStringCache()

    private let cache = NSCache<NSString, NSAttributedString>()

    private init() {
        cache.countLimit = 500
    }

    func value(for key: String) -> NSAttributedString? {
        cache.object(forKey: key as NSString)
    }

    func set(_ value: NSAttributedString, for key: String) {
        cache.setObject(value, forKey: key as NSString)
    }
}

enum HTMLTextRenderer {
    static var richLinkColor: UIColor {
        .link
    }

    private static let readMoreAttribute = NSAttributedString.Key("HackersPubReadMore")

    static func renderConfigurationKey(
        html: String,
        font: Font,
        fontSettings: FontSettingsManager,
        dynamicTypeSize: DynamicTypeSize,
        color: Color
    ) -> String {
        var hasher = Hasher()
        hasher.combine(html)
        hasher.combine(textStyle(for: font).rawValue)
        hasher.combine(fontSettings.selectedFontName)
        hasher.combine(fontSettings.fontSizeMultiplier)
        hasher.combine(fontSettings.useSystemDynamicType)
        hasher.combine(dynamicTypeSize)
        hasher.combine(color.description)
        return String(hasher.finalize())
    }

    static func textStyle(for font: Font) -> UIFont.TextStyle {
        switch font {
        case .headline:
            return .headline
        case .subheadline:
            return .subheadline
        case .caption:
            return .caption1
        case .title:
            return .title1
        default:
            return .body
        }
    }

    static func defaultWeight(for textStyle: UIFont.TextStyle) -> UIFont.Weight {
        switch textStyle {
        case .largeTitle, .title1, .title2, .title3:
            return .bold
        case .headline:
            return .semibold
        default:
            return .regular
        }
    }

    @MainActor
    static func attributedString(
        cacheKey: String,
        html: String,
        uiFont: UIFont,
        uiColor: UIColor
    ) async throws -> NSAttributedString {
        if let cached = HTMLAttributedStringCache.shared.value(for: cacheKey) {
            return cached
        }

        let rendered: NSAttributedString
        if !requiresHTMLParsing(html) {
            rendered = styledAttributedString(
                from: NSMutableAttributedString(string: html),
                uiFont: uiFont,
                uiColor: uiColor
            )
        } else {
            guard let data = html.data(using: .utf8) else {
                return styledAttributedString(
                    from: NSMutableAttributedString(string: html),
                    uiFont: uiFont,
                    uiColor: uiColor
                )
            }

            let parsed = try NSAttributedString(
                data: data,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ],
                documentAttributes: nil
            )
            rendered = styledAttributedString(from: parsed, uiFont: uiFont, uiColor: uiColor)
        }

        HTMLAttributedStringCache.shared.set(rendered, for: cacheKey)
        return rendered
    }

    @MainActor
    static func styledAttributedString(
        from attributed: NSAttributedString,
        uiFont: UIFont,
        uiColor: UIColor
    ) -> NSAttributedString {
        let mutableAttributed = NSMutableAttributedString(attributedString: attributed)
        stripReadMoreMarkers(from: mutableAttributed)
        trimTrailingWhitespace(from: mutableAttributed)
        let fullRange = NSRange(location: 0, length: mutableAttributed.length)

        guard fullRange.length > 0 else {
            return NSAttributedString(attributedString: mutableAttributed)
        }

        var fontRuns: [(UIFont?, NSRange)] = []
        mutableAttributed.enumerateAttribute(.font, in: fullRange) { value, range, _ in
            fontRuns.append((value as? UIFont, range))
        }
        for (existingFont, range) in fontRuns {
            mutableAttributed.addAttribute(
                .font,
                value: fontPreservingSemanticTraits(existingFont, on: uiFont),
                range: range
            )
        }
        mutableAttributed.addAttribute(.foregroundColor, value: uiColor, range: fullRange)

        mutableAttributed.enumerateAttribute(.paragraphStyle, in: fullRange) { value, range, _ in
            let paragraphStyle = ((value as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle)
                ?? NSMutableParagraphStyle()
            paragraphStyle.lineHeightMultiple = 1.35
            paragraphStyle.paragraphSpacingBefore = 0
            paragraphStyle.lineBreakMode = .byWordWrapping
            if NSMaxRange(range) == fullRange.length {
                paragraphStyle.paragraphSpacing = 0
            } else if paragraphStyle.paragraphSpacing == 0 {
                paragraphStyle.paragraphSpacing = uiFont.pointSize * 0.25
            }
            mutableAttributed.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)
        }

        mutableAttributed.enumerateAttribute(.link, in: fullRange) { value, range, _ in
            guard value != nil else { return }
            mutableAttributed.addAttribute(.foregroundColor, value: richLinkColor, range: range)
            mutableAttributed.addAttribute(.underlineStyle, value: 0, range: range)
        }

        mutableAttributed.enumerateAttribute(readMoreAttribute, in: fullRange) { value, range, _ in
            guard value != nil else { return }
            mutableAttributed.addAttribute(.foregroundColor, value: richLinkColor, range: range)
        }
        mutableAttributed.removeAttribute(readMoreAttribute, range: fullRange)

        return NSAttributedString(attributedString: mutableAttributed)
    }

    private static func stripReadMoreMarkers(from attributed: NSMutableAttributedString) {
        while attributed.length > 0 {
            let source = attributed.string as NSString
            let fullRange = NSRange(location: 0, length: source.length)
            let startRange = source.range(of: HTMLReadMoreMarker.start, range: fullRange)
            guard startRange.location != NSNotFound else { break }

            let contentStart = NSMaxRange(startRange)
            let remainingRange = NSRange(location: contentStart, length: source.length - contentStart)
            let endRange = source.range(of: HTMLReadMoreMarker.end, range: remainingRange)

            guard endRange.location != NSNotFound else {
                attributed.deleteCharacters(in: startRange)
                continue
            }

            let contentRange = NSRange(
                location: contentStart,
                length: endRange.location - contentStart
            )
            if contentRange.length > 0 {
                attributed.addAttribute(readMoreAttribute, value: true, range: contentRange)
            }
            attributed.deleteCharacters(in: endRange)
            attributed.deleteCharacters(in: startRange)
        }

        removeRemainingMarker(HTMLReadMoreMarker.start, from: attributed)
        removeRemainingMarker(HTMLReadMoreMarker.end, from: attributed)
    }

    private static func removeRemainingMarker(
        _ marker: String,
        from attributed: NSMutableAttributedString
    ) {
        while attributed.length > 0 {
            let source = attributed.string as NSString
            let range = source.range(
                of: marker,
                range: NSRange(location: 0, length: source.length)
            )
            guard range.location != NSNotFound else { return }
            attributed.deleteCharacters(in: range)
        }
    }

    @MainActor
    static func visibleTextFallback(
        html: String,
        uiFont: UIFont,
        uiColor: UIColor
    ) -> NSAttributedString {
        styledAttributedString(
            from: NSAttributedString(string: HTMLVisibleTextFallback.text(from: html)),
            uiFont: uiFont,
            uiColor: uiColor
        )
    }

    private static func trimTrailingWhitespace(from attributed: NSMutableAttributedString) {
        let trailingCharacters = CharacterSet.whitespacesAndNewlines
            .union(CharacterSet(charactersIn: "\u{00A0}"))

        while attributed.length > 0 {
            let lastIndex = attributed.length - 1
            let scalarValue = (attributed.string as NSString).character(at: lastIndex)
            guard let scalar = UnicodeScalar(Int(scalarValue)),
                  trailingCharacters.contains(scalar)
            else {
                break
            }

            attributed.deleteCharacters(in: NSRange(location: lastIndex, length: 1))
        }
    }

    @MainActor
    private static func fontPreservingSemanticTraits(_ existingFont: UIFont?, on selectedFont: UIFont) -> UIFont {
        guard let existingFont else { return selectedFont }

        let semanticTraits = existingFont.fontDescriptor.symbolicTraits.intersection([
            .traitBold,
            .traitItalic,
            .traitMonoSpace
        ])
        guard !semanticTraits.isEmpty else { return selectedFont }

        if semanticTraits.contains(.traitMonoSpace) {
            let weight: UIFont.Weight = semanticTraits.contains(.traitBold) ? .bold : .regular
            let monospaced = UIFont.monospacedSystemFont(ofSize: selectedFont.pointSize, weight: weight)
            if semanticTraits.contains(.traitItalic) {
                let italicTraits = monospaced.fontDescriptor.symbolicTraits.union(.traitItalic)
                if let italicDescriptor = monospaced.fontDescriptor.withSymbolicTraits(italicTraits) {
                    return UIFont(descriptor: italicDescriptor, size: selectedFont.pointSize)
                }
            }
            return monospaced
        }

        let desiredTraits = selectedFont.fontDescriptor.symbolicTraits.union(semanticTraits)
        guard let descriptor = selectedFont.fontDescriptor.withSymbolicTraits(desiredTraits) else {
            return selectedFont
        }
        return UIFont(descriptor: descriptor, size: selectedFont.pointSize)
    }

    static func requiresHTMLParsing(_ text: String) -> Bool {
        text.contains("<") || text.contains("&")
    }
}

struct HTMLTextView: View {
    let html: String
    let font: Font
    let color: Color
    let attributedStringImporter: HTMLAttributedStringImporter
    @State private var attributedText: AttributedString?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject private var fontSettings: FontSettingsManager

    init(
        html: String,
        font: Font = .body,
        color: Color = .primary,
        attributedStringImporter: HTMLAttributedStringImporter = .production
    ) {
        self.html = html
        self.font = font
        self.color = color
        self.attributedStringImporter = attributedStringImporter
    }

    var body: some View {
        Group {
            if let attributedText {
                Text(attributedText)
            } else {
                Text(HTMLVisibleTextFallback.text(from: html))
            }
        }
        .tint(Color(uiColor: HTMLTextRenderer.richLinkColor))
        .task(id: renderConfigurationKey) {
            await parseHTML(cacheKey: renderConfigurationKey)
        }
    }

    private var renderConfigurationKey: String {
        HTMLTextRenderer.renderConfigurationKey(
            html: html,
            font: font,
            fontSettings: fontSettings,
            dynamicTypeSize: dynamicTypeSize,
            color: color
        )
    }

    private var textStyle: UIFont.TextStyle {
        HTMLTextRenderer.textStyle(for: font)
    }

    @MainActor
    private func parseHTML(cacheKey: String) async {
        if let cached = HTMLAttributedStringCache.shared.value(for: cacheKey) {
            attributedText = AttributedString(cached)
            return
        }

        let weight = HTMLTextRenderer.defaultWeight(for: textStyle)
        let uiFont = fontSettings.uiFont(for: textStyle, weight: weight)
        let uiColor = UIColor(color)

        let rendered = await renderedAttributedText(
            cacheKey: cacheKey,
            uiFont: uiFont,
            uiColor: uiColor
        )
        attributedText = AttributedString(rendered)
    }

    @MainActor
    func renderedAttributedText(
        cacheKey: String,
        uiFont: UIFont,
        uiColor: UIColor
    ) async -> NSAttributedString {
        do {
            return try await attributedStringImporter(
                cacheKey: cacheKey,
                html: html,
                uiFont: uiFont,
                uiColor: uiColor
            )
        } catch {
            return HTMLTextRenderer.visibleTextFallback(
                html: html,
                uiFont: uiFont,
                uiColor: uiColor
            )
        }
    }
}
