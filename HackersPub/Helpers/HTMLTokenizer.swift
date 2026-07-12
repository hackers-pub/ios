import Foundation

// MARK: - HTMLToken

enum HTMLToken: Equatable {
    case text(String)
    case entity(raw: String, decoded: String)
    case openTag(raw: String, name: String)
    case closeTag(raw: String, name: String)
    case voidTag(raw: String, name: String)
    case unsafeContent(raw: String, name: String)
}

// MARK: - HTMLTokenizer

/// A lightweight, non-recursive HTML tokenizer.
enum HTMLTokenizer {
    static func tokenize(_ html: String) -> [HTMLToken] {
        var items: [HTMLToken] = []
        var cursor = html.startIndex

        while cursor < html.endIndex {
            switch html[cursor] {
            case "<":
                if consumeIgnoredMarkup(html: html, cursor: &cursor) {
                    continue
                }

                if let token = consumeTag(html: html, cursor: &cursor) {
                    items.append(token)
                    consumeUnsafeBlock(after: token, html: html, cursor: &cursor, items: &items)
                } else if consumeUnterminatedUnsafeMarkup(html: html, cursor: &cursor) {
                    continue
                } else {
                    items.append(.text("<"))
                    cursor = html.index(after: cursor)
                }
            case "&":
                items.append(consumeEntity(html: html, cursor: &cursor))
            default:
                let text = consumePlainText(html: html, cursor: &cursor)
                if !text.isEmpty {
                    items.append(.text(text))
                }
            }
        }

        return items
    }

    /// After an open tag for an unsafe element (script/style), consume all
    /// content up to and including the matching close tag.
    private static func consumeUnsafeBlock(
        after token: HTMLToken,
        html: String,
        cursor: inout String.Index,
        items: inout [HTMLToken]
    ) {
        guard case let .openTag(_, name) = token else { return }
        let lowerName = name.lowercased()
        guard HTMLConstants.unsafeTags.contains(lowerName) else { return }

        let closePattern = "</\(lowerName)"
        let contentStart = cursor
        while cursor < html.endIndex {
            if html[cursor] == "<", hasPrefix(closePattern, in: html, at: cursor) {
                // Verify the character after the tag name is '>' or whitespace
                // to avoid matching longer tags like </scripture> for </script>.
                let afterNameIdx = html.index(cursor, offsetBy: closePattern.count, limitedBy: html.endIndex)
                if let afterIdx = afterNameIdx, afterIdx < html.endIndex {
                    let afterChar = html[afterIdx]
                    guard afterChar == ">" || afterChar == " " || afterChar == "\t"
                        || afterChar == "\n" || afterChar == "/"
                    else {
                        cursor = html.index(after: cursor)
                        continue
                    }
                }

                let content = String(html[contentStart ..< cursor])
                items.append(.unsafeContent(raw: content, name: name))
                if let closeToken = consumeTag(html: html, cursor: &cursor) {
                    items.append(closeToken)
                } else {
                    cursor = html.endIndex
                }
                return
            }
            cursor = html.index(after: cursor)
        }
        let content = String(html[contentStart ..< cursor])
        items.append(.unsafeContent(raw: content, name: name))
    }

    /// Case-insensitive prefix check at a given index.
    private static func hasPrefix(_ prefix: String, in html: String, at start: String.Index) -> Bool {
        var htmlIdx = start
        for prefixChar in prefix {
            guard htmlIdx < html.endIndex else { return false }
            if html[htmlIdx].lowercased() != prefixChar.lowercased() {
                return false
            }
            htmlIdx = html.index(after: htmlIdx)
        }
        return true
    }

    /// Consume markup which is deliberately ignored by this lightweight parser.
    /// It remains opaque so delimiters inside it cannot be re-tokenized as HTML.
    private static func consumeIgnoredMarkup(html: String, cursor: inout String.Index) -> Bool {
        let start = cursor

        if hasPrefix("<!--", in: html, at: start) {
            return consumeOpaqueMarkup(
                html: html,
                cursor: &cursor,
                terminator: "-->"
            )
        }

        if hasPrefix("<![CDATA[", in: html, at: start) {
            return consumeOpaqueMarkup(
                html: html,
                cursor: &cursor,
                terminator: "]]>",
                searchFromOffset: "<![CDATA[".count
            )
        }

        if hasPrefix("<?", in: html, at: start) {
            let afterPrefix = html.index(start, offsetBy: 2)
            if let end = html.range(of: "?>", range: afterPrefix ..< html.endIndex)?.upperBound {
                cursor = end
            } else {
                cursor = advanceToTagClose(html: html, from: afterPrefix)
                if cursor < html.endIndex {
                    cursor = html.index(after: cursor)
                }
            }
            return true
        }

        if hasPrefix("<!", in: html, at: start) {
            let afterPrefix = html.index(start, offsetBy: 2)
            cursor = advanceToTagClose(html: html, from: afterPrefix)
            if cursor < html.endIndex {
                cursor = html.index(after: cursor)
            }
            return true
        }

        return false
    }

    private static func consumeOpaqueMarkup(
        html: String,
        cursor: inout String.Index,
        terminator: String,
        searchFromOffset: Int = 0
    ) -> Bool {
        let start = cursor
        let searchStart = html.index(start, offsetBy: searchFromOffset)
        if let end = html.range(of: terminator, range: searchStart ..< html.endIndex)?.upperBound {
            cursor = end
        } else {
            cursor = html.endIndex
        }
        return true
    }

    /// If an unsafe tag starts but never reaches a closing `>`, dropping the
    /// remainder is safer than returning a raw script/style-looking fragment.
    private static func consumeUnterminatedUnsafeMarkup(
        html: String,
        cursor: inout String.Index
    ) -> Bool {
        let start = cursor
        var probe = html.index(after: start)
        if probe < html.endIndex, html[probe] == "/" {
            probe = html.index(after: probe)
        }

        let nameStart = probe
        guard probe < html.endIndex, isASCIILetter(html[probe]) else { return false }
        while probe < html.endIndex, !isTagNameDelimiter(html[probe]) {
            probe = html.index(after: probe)
        }

        let name = String(html[nameStart ..< probe]).lowercased()
        guard HTMLConstants.unsafeTags.contains(name) else { return false }
        guard probe == html.endIndex || html[probe].isWhitespace || html[probe] == "/" else {
            return false
        }

        cursor = html.endIndex
        return true
    }
}

// MARK: - Tokenizer: Plain Text

private extension HTMLTokenizer {
    static func consumePlainText(html: String, cursor: inout String.Index) -> String {
        var text = ""
        while cursor < html.endIndex, html[cursor] != "<", html[cursor] != "&" {
            text.append(html[cursor])
            cursor = html.index(after: cursor)
        }
        return text
    }
}

// MARK: - Tokenizer: Entity

private extension HTMLTokenizer {
    static func consumeEntity(html: String, cursor: inout String.Index) -> HTMLToken {
        let start = cursor
        var probe = html.index(after: cursor)
        var length = 0
        let maxEntityLength = 32

        while probe < html.endIndex, html[probe] != ";" {
            let char = html[probe]
            if char == "<" || char == "&" || char == " " || length >= maxEntityLength {
                break
            }
            probe = html.index(after: probe)
            length += 1
        }

        if probe < html.endIndex, html[probe] == ";" {
            probe = html.index(after: probe)
            let raw = String(html[start ..< probe])
            let decoded = decodeEntity(raw)
            cursor = probe
            return .entity(raw: raw, decoded: decoded)
        }

        cursor = html.index(after: start)
        return .text("&")
    }

    static func decodeEntity(_ raw: String) -> String {
        if let scalar = decodeNumericEntity(raw) {
            return String(scalar)
        }
        return namedEntities[raw] ?? raw
    }

    static func decodeNumericEntity(_ raw: String) -> Unicode.Scalar? {
        if raw.hasPrefix("&#x") || raw.hasPrefix("&#X") {
            let hex = raw.dropFirst(3).dropLast()
            if let code = UInt32(hex, radix: 16) {
                return Unicode.Scalar(code)
            }
        } else if raw.hasPrefix("&#") {
            let dec = raw.dropFirst(2).dropLast()
            if let code = UInt32(dec) {
                return Unicode.Scalar(code)
            }
        }
        return nil
    }

    static let namedEntities: [String: String] = [
        "&amp;": "&",
        "&lt;": "<",
        "&gt;": ">",
        "&quot;": "\"",
        "&apos;": "'",
        "&nbsp;": "\u{00A0}"
    ]
}

// MARK: - Tokenizer: Tag

private extension HTMLTokenizer {
    static func consumeTag(html: String, cursor: inout String.Index) -> HTMLToken? {
        let start = cursor
        guard html[cursor] == "<" else { return nil }

        var probe = html.index(after: cursor)
        probe = advanceToTagClose(html: html, from: probe)

        guard probe < html.endIndex else { return nil }
        probe = html.index(after: probe)

        let raw = String(html[start ..< probe])

        // Classify the tag; if it's a comment/doctype/PI that returns nil,
        // restore the cursor to its original position so the caller can
        // handle the '<' as plain text without double-advancing.
        guard let token = classifyTag(raw) else {
            cursor = start
            return nil
        }

        cursor = probe
        return token
    }

    static func advanceToTagClose(html: String, from start: String.Index) -> String.Index {
        var pos = start
        while pos < html.endIndex, html[pos] != ">" {
            if html[pos] == "\"" || html[pos] == "'" {
                pos = skipQuotedValue(html: html, from: pos)
            } else {
                pos = html.index(after: pos)
            }
        }
        return pos
    }

    static func skipQuotedValue(html: String, from start: String.Index) -> String.Index {
        let quote = html[start]
        var pos = html.index(after: start)
        while pos < html.endIndex, html[pos] != quote {
            pos = html.index(after: pos)
        }
        if pos < html.endIndex {
            pos = html.index(after: pos)
        }
        return pos
    }

    static func classifyTag(_ raw: String) -> HTMLToken? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("<!--") || trimmed.hasPrefix("<!") || trimmed.hasPrefix("<?") {
            return nil
        }

        let isClose = trimmed.hasPrefix("</")
        let name = extractTagName(from: trimmed, isClose: isClose)
        guard !name.isEmpty else { return nil }

        if isClose {
            return .closeTag(raw: raw, name: name)
        }

        let lowerName = name.lowercased()
        let isSelfClosing = trimmed.hasSuffix("/>")
        if isSelfClosing || HTMLConstants.voidTags.contains(lowerName) {
            return .voidTag(raw: raw, name: name)
        }

        return .openTag(raw: raw, name: name)
    }

    static func extractTagName(from trimmed: String, isClose: Bool) -> String {
        let offset = isClose ? 2 : 1
        let nameStart = trimmed.index(trimmed.startIndex, offsetBy: offset)
        guard nameStart < trimmed.endIndex, isASCIILetter(trimmed[nameStart]) else { return "" }

        var nameEnd = nameStart
        while nameEnd < trimmed.endIndex {
            if isTagNameDelimiter(trimmed[nameEnd]) {
                break
            }
            nameEnd = trimmed.index(after: nameEnd)
        }
        return String(trimmed[nameStart ..< nameEnd])
    }

    static func isASCIILetter(_ character: Character) -> Bool {
        guard character.unicodeScalars.count == 1,
              let scalar = character.unicodeScalars.first
        else {
            return false
        }
        return (65 ... 90).contains(scalar.value) || (97 ... 122).contains(scalar.value)
    }

    static func isTagNameDelimiter(_ character: Character) -> Bool {
        character.isWhitespace || character == "/" || character == ">"
    }
}

// MARK: - Constants

enum HTMLConstants {
    static let voidTags: Set<String> = [
        "area", "base", "br", "col", "embed", "hr", "img", "input",
        "link", "meta", "param", "source", "track", "wbr"
    ]

    static let unsafeTags: Set<String> = ["script", "style"]

    static let omitCloseTags: Set<String> = ["img", "br"]
}
