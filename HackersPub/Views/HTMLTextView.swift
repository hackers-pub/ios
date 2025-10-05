import SwiftUI

struct HTMLTextView: View {
    let html: String
    let font: Font
    let color: Color
    @State private var attributedText: AttributedString?

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
    }

    private func parseHTML() async {
        guard let data = html.data(using: .utf8) else { return }

        do {
            let nsAttributed = try NSAttributedString(
                data: data,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ],
                documentAttributes: nil
            )

            let mutableAttributed = NSMutableAttributedString(attributedString: nsAttributed)
            let fullRange = NSRange(location: 0, length: mutableAttributed.length)

            // Apply font based on the font parameter
            let uiFont: UIFont
            switch font {
            case .headline:
                uiFont = UIFont.preferredFont(forTextStyle: .headline)
            case .subheadline:
                uiFont = UIFont.preferredFont(forTextStyle: .subheadline)
            case .caption:
                uiFont = UIFont.preferredFont(forTextStyle: .caption1)
            case .title:
                uiFont = UIFont.preferredFont(forTextStyle: .title1)
            default:
                uiFont = UIFont.preferredFont(forTextStyle: .body)
            }

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
