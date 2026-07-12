import Foundation

// MARK: - Options

/// Configuration for HTML string truncation.
public struct HTMLTruncateOptions {
    public let keepImageTag: Bool
    public let ellipsis: String
    /// Optional text displayed after the ellipsis when truncation occurs
    /// (e.g. "Read more"). When non-nil the text is marked so the app's HTML
    /// renderer can give it link-like emphasis without making it a URL.
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

/// Private-use characters that carry app-generated read-more semantics through
/// Foundation's HTML importer. `HTMLTextRenderer` removes both before display.
enum HTMLReadMoreMarker {
    static let start = "\u{E000}"
    static let end = "\u{E001}"
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

        return HTMLSafeTruncator.truncate(html: self, limit: limit, options: options)
    }
}

// MARK: - HTMLSafeTruncator

/// A stateless truncator that walks an HTML string token-by-token,
/// counting only visible text towards the limit while preserving the full
/// tag structure.
enum HTMLSafeTruncator {
    /// Truncate *html* so that at most *limit* visible characters remain.
    static func truncate(html: String, limit: Int, options: HTMLTruncateOptions) -> String {
        let tokens = HTMLTokenizer.tokenize(html)
        let visibleLength = visibleTextLength(of: tokens)

        guard visibleLength > limit else {
            return rebuildSafe(tokens: tokens, options: options)
        }

        return buildTruncatedOutput(tokens: tokens, limit: limit, options: options)
    }
}

// MARK: - Safe Rebuild

private struct HTMLTruncationState {
    var result = ""
    var tagStack: [String] = []
    var counted = 0
}

private extension HTMLSafeTruncator {
    /// Rebuild the HTML from tokens, stripping unsafe (script/style) content.
    static func rebuildSafe(tokens: [HTMLToken], options: HTMLTruncateOptions) -> String {
        var result = ""
        for token in tokens {
            appendSafeRebuiltToken(token, result: &result, options: options)
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
        var state = HTMLTruncationState()

        for token in tokens {
            if state.counted >= limit {
                break
            }
            processToken(
                token,
                state: &state,
                limit: limit,
                options: options
            )
        }

        if let readMore = options.readMoreText {
            appendClosingTags(to: &state.result, tagStack: state.tagStack)
            state.result += options.ellipsis
            state.result += " <span>\(HTMLReadMoreMarker.start)"
            state.result += escapeHTMLText(readMore)
            state.result += "\(HTMLReadMoreMarker.end)</span>"
        } else {
            state.result += options.ellipsis
            appendClosingTags(to: &state.result, tagStack: state.tagStack)
        }
        return state.result
    }

    static func processToken(
        _ token: HTMLToken,
        state: inout HTMLTruncationState,
        limit: Int,
        options: HTMLTruncateOptions
    ) {
        switch token {
        case let .text(value):
            let (appended, consumed) = truncateVisibleText(value, remaining: limit - state.counted)
            state.result += appended
            state.counted += consumed
        case let .entity(raw, _):
            guard state.counted < limit else { return }
            state.result += raw
            state.counted += 1
        case let .openTag(raw, name):
            processOpenTag(raw: raw, name: name, result: &state.result, tagStack: &state.tagStack)
        case let .closeTag(raw, name):
            processCloseTag(raw: raw, name: name, result: &state.result, tagStack: &state.tagStack)
        case let .voidTag(raw, name):
            appendSafeVoidTag(raw: raw, name: name, result: &state.result, options: options)
        case .unsafeContent:
            break
        }
    }

    static func appendSafeRebuiltToken(
        _ token: HTMLToken,
        result: inout String,
        options: HTMLTruncateOptions
    ) {
        switch token {
        case let .text(value):
            result += value
        case let .entity(raw, _):
            result += raw
        case let .openTag(raw, name), let .closeTag(raw, name):
            appendSafeTag(raw: raw, name: name, result: &result)
        case let .voidTag(raw, name):
            appendSafeVoidTag(raw: raw, name: name, result: &result, options: options)
        case .unsafeContent:
            break
        }
    }

    static func appendSafeTag(raw: String, name: String, result: inout String) {
        guard !HTMLConstants.unsafeTags.contains(name.lowercased()) else { return }
        result += raw
    }

    static func appendSafeVoidTag(
        raw: String,
        name: String,
        result: inout String,
        options: HTMLTruncateOptions
    ) {
        guard !HTMLConstants.unsafeTags.contains(name.lowercased()) else { return }
        guard options.keepImageTag || name.lowercased() != "img" else { return }
        result += raw
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
        if let idx = tagStack.lastIndex(where: {
            $0.caseInsensitiveCompare(name) == .orderedSame
        }) {
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
            if count >= remaining {
                break
            }
            endIndex = text.index(after: idx)
            count += 1
        }
        return (String(text[text.startIndex ..< endIndex]), count)
    }

    static func escapeHTMLText(_ text: String) -> String {
        text.reduce(into: "") { escaped, character in
            switch character {
            case "&": escaped += "&amp;"
            case "<": escaped += "&lt;"
            case ">": escaped += "&gt;"
            case "\"": escaped += "&quot;"
            case "'": escaped += "&#39;"
            default: escaped.append(character)
            }
        }
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
}
