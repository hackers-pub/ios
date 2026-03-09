import SwiftUI

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
    static let richLinkColor = UIColor(red: 0, green: 122 / 255, blue: 1, alpha: 1)

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

            let parsed = try await Task.detached(priority: .utility) {
                try NSAttributedString(
                    data: data,
                    options: [
                        .documentType: NSAttributedString.DocumentType.html,
                        .characterEncoding: String.Encoding.utf8.rawValue,
                    ],
                    documentAttributes: nil
                )
            }.value
            rendered = styledAttributedString(from: parsed, uiFont: uiFont, uiColor: uiColor)
        }

        HTMLAttributedStringCache.shared.set(rendered, for: cacheKey)
        return rendered
    }

    static func styledAttributedString(
        from attributed: NSAttributedString,
        uiFont: UIFont,
        uiColor: UIColor
    ) -> NSAttributedString {
        let mutableAttributed = NSMutableAttributedString(attributedString: attributed)
        let fullRange = NSRange(location: 0, length: mutableAttributed.length)

        guard fullRange.length > 0 else {
            return NSAttributedString(attributedString: mutableAttributed)
        }

        mutableAttributed.addAttribute(.font, value: uiFont, range: fullRange)
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

        return NSAttributedString(attributedString: mutableAttributed)
    }

    static func requiresHTMLParsing(_ text: String) -> Bool {
        text.contains("<") || text.contains("&")
    }
}

struct HTMLTextView: View {
    let html: String
    let font: Font
    let color: Color
    @State private var attributedText: AttributedString?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject private var fontSettings: FontSettingsManager

    init(html: String, font: Font = .body, color: Color = .primary) {
        self.html = html
        self.font = font
        self.color = color
    }

    var body: some View {
        Group {
            if let attributedText {
                Text(attributedText)
            } else {
                Text("")
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

    private func parseHTML(cacheKey: String) async {
        if let cached = HTMLAttributedStringCache.shared.value(for: cacheKey) {
            attributedText = AttributedString(cached)
            return
        }

        let weight = HTMLTextRenderer.defaultWeight(for: textStyle)
        let uiFont = fontSettings.uiFont(for: textStyle, weight: weight)
        let uiColor = UIColor(color)

        do {
            let rendered = try await HTMLTextRenderer.attributedString(
                cacheKey: cacheKey,
                html: html,
                uiFont: uiFont,
                uiColor: uiColor
            )
            attributedText = AttributedString(rendered)
        } catch {
            // Fallback to plain text
            attributedText = AttributedString(html)
        }
    }
}
