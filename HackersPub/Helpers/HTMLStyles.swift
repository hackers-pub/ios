import Foundation
import UIKit

enum HTMLStyles {
    // Generate CSS with dynamic font sizes based on user's text size preference
    static func generateCSS(fontSize: CGFloat, fontFamily: String = FontSettingsManager.shared.cssFontFamily) -> String {
        """
        body {
            font-family: \(fontFamily);
            font-size: \(fontSize)px;
            line-height: 1.5;
            margin: 0;
            padding: 0;
            color: light-dark(#000000, #ffffff);
        }
        h1, h2, h3, h4, h5, h6 {
            margin-top: 0.5em;
            margin-bottom: 0.25em;
            font-weight: 600;
            color: light-dark(#000000, #ffffff);
        }
        h1 { font-size: 1.5em; }
        h2 { font-size: 1.3em; }
        h3 { font-size: 1.1em; }
        p { margin: 0.25em 0; }
        code {
            background-color: light-dark(rgba(128, 128, 128, 0.15), rgba(128, 128, 128, 0.3));
            padding: 2px 4px;
            border-radius: 3px;
            font-family: Menlo, Monaco, 'Courier New', monospace;
            font-size: 0.9em;
            color: light-dark(#000000, #ffffff);
        }
        pre {
            background-color: light-dark(rgba(128, 128, 128, 0.15), rgba(128, 128, 128, 0.3));
            padding: 8px;
            border-radius: 6px;
            overflow-x: auto;
            margin: 0.25em 0;
        }
        pre code {
            background-color: transparent;
            padding: 0;
        }
        blockquote {
            margin: 0.25em 0;
            padding-left: 1em;
            border-left: 3px solid light-dark(rgba(128, 128, 128, 0.3), rgba(128, 128, 128, 0.5));
            color: light-dark(rgba(0, 0, 0, 0.7), rgba(255, 255, 255, 0.7));
        }
        ul, ol {
            margin: 0.25em 0;
            padding-left: 1.5em;
        }
        a {
            color: #007AFF;
            text-decoration: none;
        }
        strong { font-weight: 600; }
        em { font-style: italic; }
        @media (prefers-color-scheme: dark) {
            body { color: #ffffff; }
            h1, h2, h3, h4, h5, h6 { color: #ffffff; }
            code {
                background-color: rgba(128, 128, 128, 0.3);
                color: #ffffff;
            }
            pre { background-color: rgba(128, 128, 128, 0.3); }
            blockquote {
                border-left-color: rgba(128, 128, 128, 0.5);
                color: rgba(255, 255, 255, 0.7);
            }
        }
        """
    }

    static func generateComposePreviewCSS(fontSize: CGFloat, fontFamily: String = FontSettingsManager.shared.cssFontFamily) -> String {
        """
        body {
            font-family: \(fontFamily);
            font-size: \(fontSize)px;
            line-height: 1.5;
            margin: 0;
            padding: 16px;
            color: light-dark(#000000, #ffffff);
        }
        h1, h2, h3, h4, h5, h6 {
            margin-top: 1em;
            margin-bottom: 0.5em;
            font-weight: 600;
            color: light-dark(#000000, #ffffff);
        }
        h1 { font-size: 2em; }
        h2 { font-size: 1.5em; }
        h3 { font-size: 1.25em; }
        p { margin: 0.5em 0; }
        code {
            background-color: light-dark(rgba(128, 128, 128, 0.15), rgba(128, 128, 128, 0.3));
            padding: 2px 4px;
            border-radius: 3px;
            font-family: Menlo, Monaco, 'Courier New', monospace;
            font-size: 0.9em;
            color: light-dark(#000000, #ffffff);
        }
        pre {
            background-color: light-dark(rgba(128, 128, 128, 0.15), rgba(128, 128, 128, 0.3));
            padding: 12px;
            border-radius: 6px;
            overflow-x: auto;
        }
        pre code {
            background-color: transparent;
            padding: 0;
        }
        blockquote {
            margin: 0.5em 0;
            padding-left: 1em;
            border-left: 3px solid light-dark(rgba(128, 128, 128, 0.3), rgba(128, 128, 128, 0.5));
            color: light-dark(rgba(0, 0, 0, 0.7), rgba(255, 255, 255, 0.7));
        }
        ul, ol {
            margin: 0.5em 0;
            padding-left: 2em;
        }
        a {
            color: #007AFF;
            text-decoration: none;
        }
        strong { font-weight: 600; }
        em { font-style: italic; }
        @media (prefers-color-scheme: dark) {
            body { color: #ffffff; }
            h1, h2, h3, h4, h5, h6 { color: #ffffff; }
            code {
                background-color: rgba(128, 128, 128, 0.3);
                color: #ffffff;
            }
            pre { background-color: rgba(128, 128, 128, 0.3); }
            blockquote {
                border-left-color: rgba(128, 128, 128, 0.5);
                color: rgba(255, 255, 255, 0.7);
            }
        }
        """
    }

    // Default CSS using system body font size
    static var defaultCSS: String {
        let fontSettings = FontSettingsManager.shared
        let fontSize = fontSettings.scaledSize(for: .body)
        return generateCSS(fontSize: fontSize, fontFamily: fontSettings.cssFontFamily)
    }

    // Compose preview CSS using custom font settings
    static var composePreviewCSS: String {
        let fontSettings = FontSettingsManager.shared
        let fontSize = fontSettings.scaledSize(for: .body)
        return generateComposePreviewCSS(fontSize: fontSize, fontFamily: fontSettings.cssFontFamily)
    }

    static func wrapHTML(_ content: String, css: String = defaultCSS) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>\(css)</style>
        </head>
        <body>
        \(content)
        </body>
        </html>
        """
    }
}
