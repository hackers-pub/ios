import Foundation

// MARK: - Options

/// Configuration for HTML string truncation.
public struct HTMLTruncateOptions {
    public let keepImageTag: Bool
    public let ellipsis: String
    /// Optional text displayed after the ellipsis when truncation occurs
    /// (e.g. "Read more"). When non-nil the text is wrapped in a styled
    /// `<span>` so it appears as a link-like indicator inside the HTML.
    public let readMoreText: String?

    public init(
        keepImageTag: Bool = false,
        ellipsis: String = "\u{2026}",
        readMoreText: String? = nil
    ) {
        self.keepImageTag = keepImageTag
        self.ellipsis = ellipsis
        self.readMoreText = readMoreText
    }

    public static let `default` = HTMLTruncateOptions()
}

// MARK: - String Extension

public extension String {
    /// Truncate an HTML string by visible text length while preserving tag structure.
    ///
    /// The implementation counts only visible text characters (excluding HTML tags)
    /// and closes any open tags after the truncation point. HTML entities such as
    /// `&amp;` count as a single visible character.
    func htmlTruncated(limit: Int, options: HTMLTruncateOptions = .default) -> String {
        guard limit > 0 else { return "" }

        do {
            return try HTMLSafeTruncator.truncate(html: self, limit: limit, options: options)
        } catch {
            return self
        }
    }
}

// MARK: - HTMLSafeTruncator

/// A stateless truncator that walks an HTML string token-by-token,
/// counting only visible text towards the limit while preserving the full
/// tag structure.
enum HTMLSafeTruncator {
    /// Truncate *html* so that at most *limit* visible characters remain.
    static func truncate(html: String, limit: Int, options: HTMLTruncateOptions) throws -> String {
        let tokens = try HTMLTokenizer.tokenize(html)
        let visibleLength = visibleTextLength(of: tokens)

        guard visibleLength > limit else {
            let safe = rebuildSafe(tokens: tokens)
            return options.keepImageTag ? safe : stripImgTags(safe)
        }

        let truncated = buildTruncatedOutput(tokens: tokens, limit: limit, options: options)
        return options.keepImageTag ? truncated : stripImgTags(truncated)
    }
}

// MARK: - Safe Rebuild

private extension HTMLSafeTruncator {
    /// Rebuild the HTML from tokens, stripping unsafe (script/style) content.
    static func rebuildSafe(tokens: [HTMLToken]) -> String {
        var result = ""
        for token in tokens {
            switch token {
            case let .text(value):
                result += value
            case let .entity(raw, _):
                result += raw
            case let .openTag(raw, name):
                guard !HTMLConstants.unsafeTags.contains(name.lowercased()) else { continue }
                result += raw
            case let .closeTag(raw, name):
                guard !HTMLConstants.unsafeTags.contains(name.lowercased()) else { continue }
                result += raw
            case let .voidTag(raw, name):
                guard !HTMLConstants.unsafeTags.contains(name.lowercased()) else { continue }
                result += raw
            case .unsafeContent:
                continue
            }
        }
        return result
    }
}

// MARK: - Output Builder

private extension HTMLSafeTruncator {
    static func buildTruncatedOutput(
        tokens: [HTMLToken],
        limit: Int,
        options: HTMLTruncateOptions
    ) -> String {
        var result = ""
        var tagStack: [String] = []
        var counted = 0

        for token in tokens {
            if counted >= limit { break }
            processToken(token, result: &result, tagStack: &tagStack, counted: &counted, limit: limit)
        }

        result += options.ellipsis
        if let readMore = options.readMoreText {
            // Use system link color via -apple-system-link so the indicator
            // adapts to Light / Dark Mode automatically.
            result += " <span style=\"color: -apple-system-link;\">\(readMore)</span>"
        }
        appendClosingTags(to: &result, tagStack: tagStack)
        return result
    }

    static func processToken(
        _ token: HTMLToken,
        result: inout String,
        tagStack: inout [String],
        counted: inout Int,
        limit: Int
    ) {
        switch token {
        case let .text(value):
            let (appended, consumed) = truncateVisibleText(value, remaining: limit - counted)
            result += appended
            counted += consumed
        case let .entity(raw, _):
            guard counted < limit else { return }
            result += raw
            counted += 1
        case let .openTag(raw, name):
            processOpenTag(raw: raw, name: name, result: &result, tagStack: &tagStack)
        case let .closeTag(raw, name):
            processCloseTag(raw: raw, name: name, result: &result, tagStack: &tagStack)
        case let .voidTag(raw, name):
            guard !HTMLConstants.unsafeTags.contains(name.lowercased()) else { return }
            result += raw
        case .unsafeContent:
            break
        }
    }

    static func processOpenTag(
        raw: String,
        name: String,
        result: inout String,
        tagStack: inout [String]
    ) {
        guard !HTMLConstants.unsafeTags.contains(name.lowercased()) else { return }
        result += raw
        if !HTMLConstants.voidTags.contains(name.lowercased()) {
            tagStack.append(name)
        }
    }

    static func processCloseTag(
        raw: String,
        name: String,
        result: inout String,
        tagStack: inout [String]
    ) {
        guard !HTMLConstants.unsafeTags.contains(name.lowercased()) else { return }
        if let idx = tagStack.lastIndex(of: name) {
            tagStack.remove(at: idx)
        }
        result += raw
    }

    static func appendClosingTags(to result: inout String, tagStack: [String]) {
        let tagsToClose = tagStack.reversed()
            .filter { !HTMLConstants.omitCloseTags.contains($0.lowercased()) }
        for tag in tagsToClose {
            result += "</\(tag)>"
        }
    }

    static func truncateVisibleText(
        _ text: String,
        remaining: Int
    ) -> (appended: String, consumed: Int) {
        guard remaining > 0 else { return ("", 0) }
        var count = 0
        var endIndex = text.startIndex
        for idx in text.indices {
            if count >= remaining { break }
            endIndex = text.index(after: idx)
            count += 1
        }
        return (String(text[text.startIndex ..< endIndex]), count)
    }

    static func visibleTextLength(of tokens: [HTMLToken]) -> Int {
        tokens.reduce(0) { acc, token in
            switch token {
            case let .text(value): return acc + value.count
            case .entity: return acc + 1
            default: return acc
            }
        }
    }

    static func stripImgTags(_ html: String) -> String {
        guard let regex = try? Regex(#"<img\s[^>]*>"#).ignoresCase() else {
            return html
        }
        return html.replacing(regex, with: "")
    }
}
