import Foundation

/// Fast, non-WebKit text used while the rich attributed renderer is preparing.
/// It deliberately ignores comments and executable/style blocks instead of
/// attempting to fully parse or render remote HTML on the initial layout pass.
enum HTMLVisibleTextFallback {
    struct ScanResult {
        let text: String
        let unsafeTagPrefixCharactersInspected: Int
    }

    static func text(from html: String) -> String {
        scan(html).text
    }

    static func scan(_ html: String) -> ScanResult {
        var output = ""
        var index = html.startIndex
        var unsafeTagPrefixCharactersInspected = 0

        while index < html.endIndex {
            guard html[index] == "<" else {
                output.append(html[index])
                index = html.index(after: index)
                continue
            }

            if html[index...].hasPrefix("<!--") {
                index = afterComment(in: html, from: index)
                appendSeparator(to: &output)
                continue
            }

            if let unsafeName = unsafeTagName(
                in: html,
                from: index,
                charactersInspected: &unsafeTagPrefixCharactersInspected
            ) {
                index = afterUnsafeBlock(named: unsafeName, in: html, from: index)
                appendSeparator(to: &output)
                continue
            }

            guard let end = tagEnd(in: html, from: index) else {
                appendSeparator(to: &output)
                break
            }
            index = html.index(after: end)
            appendSeparator(to: &output)
        }

        let text = decodeCommonEntities(in: output)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        return ScanResult(
            text: text,
            unsafeTagPrefixCharactersInspected: unsafeTagPrefixCharactersInspected
        )
    }

    private static func unsafeTagName(
        in html: String,
        from start: String.Index,
        charactersInspected: inout Int
    ) -> String? {
        if hasASCIIName(
            "script",
            in: html,
            after: start,
            charactersInspected: &charactersInspected
        ) {
            return "script"
        }
        if hasASCIIName(
            "style",
            in: html,
            after: start,
            charactersInspected: &charactersInspected
        ) {
            return "style"
        }
        return nil
    }

    private static func hasASCIIName(
        _ name: String,
        in html: String,
        after tagStart: String.Index,
        charactersInspected: inout Int
    ) -> Bool {
        let scalars = html.unicodeScalars
        var index = scalars.index(after: tagStart)

        for expected in name.unicodeScalars {
            guard index < scalars.endIndex else { return false }
            charactersInspected += 1
            guard lowercasedASCII(scalars[index].value) == expected.value else { return false }
            index = scalars.index(after: index)
        }

        guard index < scalars.endIndex else { return true }
        charactersInspected += 1
        let boundary = scalars[index]
        return CharacterSet.whitespacesAndNewlines.contains(boundary) ||
            boundary == ">" ||
            boundary == "/"
    }

    private static func lowercasedASCII(_ value: UInt32) -> UInt32 {
        (65 ... 90).contains(value) ? value + 32 : value
    }

    private static func afterUnsafeBlock(
        named name: String,
        in html: String,
        from start: String.Index
    ) -> String.Index {
        guard let openingEnd = tagEnd(in: html, from: start) else { return html.endIndex }
        let contentStart = html.index(after: openingEnd)
        return HTMLRawTextScanner.indexAfterClosingTag(named: name, in: html, from: contentStart) ?? html.endIndex
    }

    private static func afterComment(
        in html: String,
        from start: String.Index
    ) -> String.Index {
        guard let range = html.range(of: "-->", range: start ..< html.endIndex) else {
            return html.endIndex
        }
        return range.upperBound
    }

    private static func tagEnd(in html: String, from start: String.Index) -> String.Index? {
        var index = html.index(after: start)
        var quote: Character?

        while index < html.endIndex {
            let character = html[index]
            if let activeQuote = quote {
                if character == activeQuote {
                    quote = nil
                }
            } else if character == "\"" || character == "'" {
                quote = character
            } else if character == ">" {
                return index
            }
            index = html.index(after: index)
        }
        return nil
    }

    private static func appendSeparator(to output: inout String) {
        guard output.last?.isWhitespace != true else { return }
        output.append(" ")
    }

    private static func decodeCommonEntities(in value: String) -> String {
        value
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
    }
}
