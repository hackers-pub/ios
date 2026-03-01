import SwiftUI

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
        .task(id: html) {
            await parseHTML()
        }
        .onChange(of: dynamicTypeSize) { _, _ in
            Task {
                await parseHTML()
            }
        }
        .onChange(of: fontSettings.selectedFontName) { _, _ in
            Task {
                await parseHTML()
            }
        }
        .onChange(of: fontSettings.fontSizeMultiplier) { _, _ in
            Task {
                await parseHTML()
            }
        }
        .onChange(of: fontSettings.useSystemDynamicType) { _, _ in
            Task {
                await parseHTML()
            }
        }
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

    private func parseHTML() async {
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
            let weight = Self.defaultWeight(for: textStyle)
            let uiFont = fontSettings.uiFont(for: textStyle, weight: weight)
            mutableAttributed.addAttribute(.font, value: uiFont, range: fullRange)

            let uiColor = UIColor(color)
            mutableAttributed.addAttribute(.foregroundColor, value: uiColor, range: fullRange)

            attributedText = AttributedString(mutableAttributed)
        } catch {
            // Fallback to plain text
            attributedText = AttributedString(html)
        }
    }
}
