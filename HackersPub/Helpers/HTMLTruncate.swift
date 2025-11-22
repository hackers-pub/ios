import Foundation

// MARK: - Options

/// struct to configure the HTML string truncation
public struct HTMLTruncateOptions {
    public let keepImageTag: Bool
    public let truncateLastWord: Bool
    public let slop: Int
    public let ellipsis: String

    public init(
        keepImageTag: Bool = false,
        truncateLastWord: Bool = true,
        slop: Int = 10,
        ellipsis: String = "..."
    ) {
        self.keepImageTag = keepImageTag
        self.truncateLastWord = truncateLastWord
        self.slop = slop
        self.ellipsis = ellipsis
    }

    public static let `default` = HTMLTruncateOptions()
}

// MARK: - String Extension

public extension String {

    /// truncate string safely with keep html tags
    func htmlTruncated(limit: Int, options: HTMLTruncateOptions = .default) -> String {
        let effectiveSlopyb = min(options.slop, limit)
        let slop = options.slop > limit ? limit : effectiveSlopyb
        
        var tagStack: [String] = []
        var currentTextLength = 0
        var result = ""
        var currentIndex = self.startIndex
        
        let attrPattern = #"[a-zA-Z0-9-]+\s*=\s*"[^"]*"\s*"#
        let tagPattern = try! Regex(#"<\/?([a-zA-Z0-9]+)(?:\s*(?:\#(attrPattern))*)?\s*\/?>"#)
        
        let matches = self.matches(of: tagPattern)
        for match in matches {
            let textBeforeTag = self[currentIndex..<match.range.lowerBound]
            let textCount = textBeforeTag.count
            
            if currentTextLength + textCount > limit {
                let remainingLimit = limit - currentTextLength
                let cutPosition = calculateEndPosition(
                    text: String(textBeforeTag),
                    limit: remainingLimit,
                    slop: slop,
                    truncateLastWord: options.truncateLastWord
                )
                
                result += textBeforeTag.prefix(cutPosition)
                currentIndex = match.range.lowerBound
                currentTextLength = limit + 1
                break
            }
            
            // 텍스트 추가
            result += textBeforeTag
            currentTextLength += textCount
            
            // process tag
            let tagString = String(self[match.range])
            guard let tagNameSubstring = match.output[1].substring else { continue }
            let tagName = String(tagNameSubstring)
            
            if tagString.hasPrefix("</") {
                // close tag
                if tagStack.last == tagName {
                    tagStack.removeLast()
                }
            } else if !tagString.hasSuffix("/>") && !HTMLConstants.voidTags.contains(tagName.lowercased()) {
                // open tag, add to stack
                tagStack.append(tagName)
            }
            
            // tag itself is not included in the length and added to the result
            result += tagString
            currentIndex = match.range.upperBound
        }
        
        // process remaining text
        if currentTextLength <= limit && currentIndex < self.endIndex {
            let remainingText = self[currentIndex...]
            let remainingLimit = limit - currentTextLength
            
            if remainingText.count > remainingLimit {
                let cutPosition = calculateEndPosition(
                    text: String(remainingText),
                    limit: remainingLimit,
                    slop: slop,
                    truncateLastWord: options.truncateLastWord
                )
                result += remainingText.prefix(cutPosition)
            } else {
                result += remainingText
            }
        }

        // check need to add ellipsis
        let plainTextLength = self.replacing(tagPattern, with: "").count
        if plainTextLength > limit {
            result += options.ellipsis
        }
        
        // close open tags
        result += tagStack.reversed()
            .filter { !HTMLConstants.excludeTags.contains($0) }
            .map { "</\($0)>" }
            .joined()
        
        // process image tag
        if !options.keepImageTag {
            // remove image tag
            result = result.replacing(try! Regex(#"<img\s+[^>]*>"#).ignoresCase(), with: "")
        }
        
        return result
    }
    
    // MARK: - Helper Methods
    
    /// calculate the position to truncate the text
    private func calculateEndPosition(text: String, limit: Int, slop: Int, truncateLastWord: Bool) -> Int {
        if truncateLastWord || limit <= slop {
            return limit
        }
        
        // find the word boundary near the limit
        let searchRangeStart = text.index(text.startIndex, offsetBy: max(0, limit - slop))
        let searchRangeEnd = text.index(text.startIndex, offsetBy: min(text.count, limit + slop))
        let searchRange = searchRangeStart..<searchRangeEnd
        let substring = text[searchRange]
        
        // find the word boundary
        let wordBreakPattern = try! Regex(#"\W+"#)
        let matches = substring.matches(of: wordBreakPattern)
        
        // find the word boundary near the limit
        var bestCutIndex = text.index(text.startIndex, offsetBy: limit)
        var minDistance = Int.max
        
        for match in matches {
            let distance = abs(text.distance(from: match.range.lowerBound, to: bestCutIndex))
            if distance < minDistance {
                minDistance = distance
                bestCutIndex = match.range.lowerBound
            }
        }
        
        return text.distance(from: text.startIndex, to: bestCutIndex)
    }
}

// MARK: - Constants

private enum HTMLConstants {
    /// tags that don't need a closing tag
    static let voidTags: Set<String> = ["area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "param", "source", "track", "wbr"]
    
    /// tags that don't need a closing tag
    static let excludeTags: Set<String> = ["img", "br"]
}
