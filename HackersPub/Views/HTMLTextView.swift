import SwiftUI

private final class HTMLAttributedStringCache {
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
        .task(id: renderConfigurationKey) {
            await parseHTML(cacheKey: renderConfigurationKey)
        }
    }

    private var renderConfigurationKey: String {
        var hasher = Hasher()
        hasher.combine(html)
        hasher.combine(textStyle.rawValue)
        hasher.combine(fontSettings.selectedFontName)
        hasher.combine(fontSettings.fontSizeMultiplier)
        hasher.combine(fontSettings.useSystemDynamicType)
        hasher.combine(dynamicTypeSize)
        hasher.combine(color.description)
        return String(hasher.finalize())
    }

    private var textStyle: UIFont.TextStyle {
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

    /// Returns the default `UIFont.Weight` that matches the semantic meaning
    /// of the given text style (e.g. headlines are semibold, titles are bold).
    private static func defaultWeight(for textStyle: UIFont.TextStyle) -> UIFont.Weight {
        switch textStyle {
        case .largeTitle, .title1, .title2, .title3:
            return .bold
        case .headline:
            return .semibold
        default:
            return .regular
        }
    }

    private func parseHTML(cacheKey: String) async {
        if let cached = HTMLAttributedStringCache.shared.value(for: cacheKey) {
            attributedText = AttributedString(cached)
            return
        }

        let weight = Self.defaultWeight(for: textStyle)
        let uiFont = fontSettings.uiFont(for: textStyle, weight: weight)
        let uiColor = UIColor(color)

        if !Self.requiresHTMLParsing(html) {
            let plain = NSMutableAttributedString(string: html)
            let fullRange = NSRange(location: 0, length: plain.length)
            plain.addAttribute(.font, value: uiFont, range: fullRange)
            plain.addAttribute(.foregroundColor, value: uiColor, range: fullRange)
            let cachedValue = NSAttributedString(attributedString: plain)
            HTMLAttributedStringCache.shared.set(cachedValue, for: cacheKey)
            attributedText = AttributedString(cachedValue)
            return
        }

        guard let data = html.data(using: .utf8) else { return }

        do {
            let nsAttributed = try NSAttributedString(
                data: data,
                // swiftformat:disable trailingCommas
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ],
                // swiftformat:enable trailingCommas
                documentAttributes: nil
            )

            let mutableAttributed = NSMutableAttributedString(attributedString: nsAttributed)
            let fullRange = NSRange(location: 0, length: mutableAttributed.length)

            // Apply user-selected font and size from FontSettingsManager,
            // preserving the semantic bold/semibold weight for heading styles.
            mutableAttributed.addAttribute(.font, value: uiFont, range: fullRange)

            mutableAttributed.addAttribute(.foregroundColor, value: uiColor, range: fullRange)

            let cachedValue = NSAttributedString(attributedString: mutableAttributed)
            HTMLAttributedStringCache.shared.set(cachedValue, for: cacheKey)
            attributedText = AttributedString(cachedValue)
        } catch {
            // Fallback to plain text
            attributedText = AttributedString(html)
        }
    }

    private static func requiresHTMLParsing(_ text: String) -> Bool {
        text.contains("<") || text.contains("&")
    }
}
