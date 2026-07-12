import Foundation

/// A deliberately small HTML sanitizer for remote server content.
///
/// Rendering CSS is applied by the app, so server markup is limited to the
/// formatting and media elements the renderer supports.  This is independent
/// from feed truncation: every rich WebKit load crosses this boundary.
enum HTMLServerContentSanitizer {
    private static let allowedTags: Set<String> = [
        "a", "article", "audio", "b", "blockquote", "br", "code", "dd", "del", "details", "div", "dl", "dt",
        "em", "figcaption", "figure", "h1", "h2", "h3", "h4", "h5", "h6", "hr", "i", "img", "li",
        "mark", "ol", "p", "picture", "pre", "s", "section", "small", "source", "span", "strong", "sub", "summary",
        "sup", "table", "tbody", "td", "tfoot", "th", "thead", "track", "tr", "u", "ul", "video"
    ]

    private static let voidTags: Set<String> = ["br", "hr", "img", "source", "track"]
    private static let discardContentsTags: Set<String> = [
        "form", "frameset", "iframe", "math", "object", "script", "style", "svg", "template"
    ]
    private static let discardOnlyTags: Set<String> = ["base", "embed", "frame", "link", "meta"]

    private static let globalAttributes: Set<String> = ["title"]
    private static let tagAttributes: [String: Set<String>] = [
        "a": ["href"],
        "audio": ["autoplay", "controls", "loop", "muted", "preload", "src"],
        "img": ["alt", "height", "src", "width"],
        "li": ["value"],
        "ol": ["start", "type"],
        "source": ["src", "type"],
        "td": ["colspan", "rowspan"],
        "th": ["colspan", "rowspan"],
        "track": ["kind", "label", "src", "srclang"],
        "video": ["autoplay", "controls", "height", "loop", "muted", "playsinline", "poster", "preload", "src", "width"]
    ]
    private static let urlAttributes: Set<String> = ["href", "poster", "src"]
    private static let booleanAttributes: Set<String> = ["autoplay", "controls", "loop", "muted", "playsinline"]
    private static let numericAttributes: Set<String> = ["colspan", "height", "rowspan", "start", "value", "width"]

    static func sanitize(_ html: String) -> String {
        var output = ""
        var index = html.startIndex

        while index < html.endIndex {
            guard html[index] == "<" else {
                output.append(html[index])
                index = html.index(after: index)
                continue
            }

            if html[index...].hasPrefix("<!--") {
                index = indexAfterComment(in: html, from: index)
                continue
            }

            if html[index...].hasPrefix("<!") || html[index...].hasPrefix("<?") {
                index = indexAfterDeclaration(in: html, from: index)
                continue
            }

            guard let tagEnd = tagEnd(in: html, from: index),
                  let tag = parseTag(String(html[index ... tagEnd]))
            else {
                output += "&lt;"
                index = html.index(after: index)
                continue
            }

            index = sanitizedTagEndIndex(
                for: tag,
                in: html,
                after: html.index(after: tagEnd),
                output: &output
            )
        }

        return output
    }

    private static func sanitizedTagEndIndex(
        for tag: Tag,
        in html: String,
        after tagEnd: String.Index,
        output: inout String
    ) -> String.Index {
        if discardContentsTags.contains(tag.name) {
            guard !tag.isClosing, !voidTags.contains(tag.name) else { return tagEnd }
            return indexAfterDiscardedElement(named: tag.name, in: html, from: tagEnd)
        }

        guard !discardOnlyTags.contains(tag.name), allowedTags.contains(tag.name) else {
            return tagEnd
        }

        if tag.isClosing {
            guard !voidTags.contains(tag.name) else { return tagEnd }
            output += "</\(tag.name)>"
            return tagEnd
        }

        output += "<\(tag.name)"
        for attribute in sanitizedAttributes(for: tag) {
            output += " \(attribute)"
        }
        output += ">"
        return tagEnd
    }

    private struct Tag {
        let name: String
        let isClosing: Bool
        let attributes: [(name: String, value: String?)]
    }

    private static func parseTag(_ raw: String) -> Tag? {
        guard raw.first == "<", raw.last == ">" else { return nil }

        var body = String(raw.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        var isClosing = false
        if body.hasPrefix("/") {
            isClosing = true
            body.removeFirst()
            body = body.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let nameEnd = body.firstIndex(where: { !$0.isHTMLTagNameCharacter }), nameEnd > body.startIndex else {
            guard !body.isEmpty, body.allSatisfy(\.isHTMLTagNameCharacter) else { return nil }
            let name = body.lowercased()
            guard name.first?.isASCIILetter == true else { return nil }
            return Tag(name: name, isClosing: isClosing, attributes: [])
        }

        let name = String(body[..<nameEnd]).lowercased()
        guard name.first?.isASCIILetter == true else { return nil }
        return Tag(
            name: name,
            isClosing: isClosing,
            attributes: isClosing ? [] : parseAttributes(String(body[nameEnd...]))
        )
    }

    private static func parseAttributes(_ source: String) -> [(name: String, value: String?)] {
        var attributes: [(name: String, value: String?)] = []
        var index = source.startIndex

        while index < source.endIndex {
            skipWhitespace(in: source, index: &index)
            guard index < source.endIndex else { break }

            let nameStart = index
            while index < source.endIndex, source[index].isHTMLAttributeNameCharacter {
                index = source.index(after: index)
            }
            guard index > nameStart else {
                index = source.index(after: index)
                continue
            }

            let name = String(source[nameStart ..< index]).lowercased()
            skipWhitespace(in: source, index: &index)

            var value: String?
            if index < source.endIndex, source[index] == "=" {
                index = source.index(after: index)
                skipWhitespace(in: source, index: &index)
                value = readAttributeValue(in: source, index: &index)
            }
            attributes.append((name, value))
        }

        return attributes
    }

    private static func readAttributeValue(in source: String, index: inout String.Index) -> String {
        guard index < source.endIndex else { return "" }

        if source[index] == "\"" || source[index] == "'" {
            let quote = source[index]
            index = source.index(after: index)
            let valueStart = index
            while index < source.endIndex, source[index] != quote {
                index = source.index(after: index)
            }
            let value = String(source[valueStart ..< index])
            if index < source.endIndex {
                index = source.index(after: index)
            }
            return value
        }

        let valueStart = index
        while index < source.endIndex, !source[index].isHTMLUnquotedAttributeValueDelimiter {
            index = source.index(after: index)
        }
        return String(source[valueStart ..< index])
    }

    private static func sanitizedAttributes(for tag: Tag) -> [String] {
        let allowed = globalAttributes.union(tagAttributes[tag.name] ?? [])
        var rendered: [String] = []

        for attribute in tag.attributes {
            guard allowed.contains(attribute.name) else { continue }

            if booleanAttributes.contains(attribute.name) {
                rendered.append(attribute.name)
                continue
            }

            guard let rawValue = attribute.value else { continue }
            let value = decodeEntities(rawValue)
            guard !value.isEmpty else { continue }

            if urlAttributes.contains(attribute.name), !isAllowedHTTPURL(value) {
                continue
            }
            if numericAttributes.contains(attribute.name), Int(value) == nil {
                continue
            }

            rendered.append("\(attribute.name)=\"\(escapeAttribute(value))\"")
        }

        return rendered
    }

    private static func isAllowedHTTPURL(_ value: String) -> Bool {
        guard let components = URLComponents(string: value),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              components.host?.isEmpty == false
        else {
            return false
        }
        return true
    }

    private static func escapeAttribute(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func decodeEntities(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
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

    private static func indexAfterComment(in html: String, from start: String.Index) -> String.Index {
        guard let range = html.range(of: "-->", range: start ..< html.endIndex) else {
            return html.endIndex
        }
        return range.upperBound
    }

    private static func indexAfterDeclaration(in html: String, from start: String.Index) -> String.Index {
        guard let end = tagEnd(in: html, from: start) else { return html.endIndex }
        return html.index(after: end)
    }

    private static func indexAfterDiscardedElement(
        named name: String,
        in html: String,
        from start: String.Index
    ) -> String.Index {
        HTMLRawTextScanner.indexAfterClosingTag(named: name, in: html, from: start) ?? html.endIndex
    }

    private static func skipWhitespace(in source: String, index: inout String.Index) {
        while index < source.endIndex, source[index].isWhitespace {
            index = source.index(after: index)
        }
    }
}

private extension Character {
    var isASCIILetter: Bool {
        ("A" ... "Z").contains(self) || ("a" ... "z").contains(self)
    }

    var isHTMLTagNameCharacter: Bool {
        isASCIILetter || isNumber || self == ":" || self == "-"
    }

    var isHTMLAttributeNameCharacter: Bool {
        isHTMLTagNameCharacter || self == "_"
    }

    var isHTMLUnquotedAttributeValueDelimiter: Bool {
        isWhitespace || self == "\"" || self == "'" || self == "`" || self == "=" || self == "<" || self == ">"
    }
}
