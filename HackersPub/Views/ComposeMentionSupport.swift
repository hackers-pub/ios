import CoreGraphics
import Foundation

struct ComposeMentionMatch: Equatable {
    let query: String
    let range: NSRange

    static func == (lhs: ComposeMentionMatch, rhs: ComposeMentionMatch) -> Bool {
        lhs.query == rhs.query
            && lhs.range.location == rhs.range.location
            && lhs.range.length == rhs.range.length
    }
}

enum ComposeMentionSupport {
    private static let querySeparators = CharacterSet.whitespacesAndNewlines
        .union(CharacterSet(charactersIn: "<>()[]{}\"'`,!?;:"))

    static func activeMention(
        in content: String,
        selectedRange: NSRange
    ) -> ComposeMentionMatch? {
        let nsContent = content as NSString
        let cursor = max(0, min(selectedRange.location, nsContent.length))
        guard selectedRange.length == 0, cursor > 0 else { return nil }

        let beforeCursor = nsContent.substring(to: cursor) as NSString
        var searchLength = beforeCursor.length

        while searchLength > 0 {
            let atRange = beforeCursor.range(
                of: "@",
                options: .backwards,
                range: NSRange(location: 0, length: searchLength)
            )
            guard atRange.location != NSNotFound else { return nil }

            let startsAtBoundary: Bool
            if atRange.location > 0 {
                let previous = beforeCursor.character(at: atRange.location - 1)
                startsAtBoundary = isMentionBoundary(previous)
            } else {
                startsAtBoundary = true
            }

            guard startsAtBoundary else {
                searchLength = atRange.location
                continue
            }

            let queryLocation = atRange.location + 1
            let queryLength = cursor - queryLocation
            guard queryLength > 0 else { return nil }

            let query = beforeCursor.substring(
                with: NSRange(location: queryLocation, length: queryLength)
            )
            guard isValidQuery(query) else { return nil }

            return ComposeMentionMatch(
                query: query,
                range: NSRange(
                    location: atRange.location,
                    length: cursor - atRange.location
                )
            )
        }

        return nil
    }

    static func replacementRange(
        in content: String,
        mention: ComposeMentionMatch
    ) -> NSRange {
        let nsContent = content as NSString
        var end = min(mention.range.location + mention.range.length, nsContent.length)

        while end < nsContent.length {
            let character = nsContent.character(at: end)
            guard !CharacterSet.whitespacesAndNewlines.containsUnicodeScalar(character) else {
                end += 1
                while end < nsContent.length {
                    let nextCharacter = nsContent.character(at: end)
                    guard CharacterSet.whitespacesAndNewlines
                        .containsUnicodeScalar(nextCharacter)
                    else {
                        break
                    }
                    end += 1
                }
                break
            }

            let currentQuery = nsContent.substring(
                with: NSRange(
                    location: mention.range.location + 1,
                    length: end - mention.range.location - 1
                )
            )
            guard isContinuationCharacter(character, after: currentQuery) else { break }
            end += 1
        }

        return NSRange(
            location: mention.range.location,
            length: end - mention.range.location
        )
    }

    private static func isValidQuery(_ query: String) -> Bool {
        guard query.count <= 80,
              query.rangeOfCharacter(from: querySeparators) == nil
        else {
            return false
        }

        let handleParts = query.split(separator: "@", omittingEmptySubsequences: false)
        guard (1 ... 2).contains(handleParts.count),
              let username = handleParts.first,
              isValidUsernamePart(String(username))
        else {
            return false
        }

        if handleParts.count == 2 {
            return handleParts[1].isEmpty || isValidHostPrefix(String(handleParts[1]))
        }

        return true
    }

    private static func isMentionBoundary(_ utf16Value: unichar) -> Bool {
        guard let scalar = UnicodeScalar(Int(utf16Value)) else { return false }
        return CharacterSet.whitespacesAndNewlines.contains(scalar)
            || CharacterSet(charactersIn: "([{").contains(scalar)
    }

    private static func isValidUsernamePart(_ username: String) -> Bool {
        guard !username.isEmpty else { return false }

        let scalars = Array(username.unicodeScalars)
        for (index, scalar) in scalars.enumerated() {
            if isASCIILetterOrDigit(scalar) || scalar == "_" {
                continue
            }

            let isSeparator = scalar == "." || scalar == "-"
            let isInteriorSeparator = index > 0 && index < scalars.count - 1
            if isSeparator && isInteriorSeparator {
                continue
            }

            return false
        }

        return true
    }

    private static func isValidHostPrefix(_ host: String) -> Bool {
        guard host.count <= 253 else { return false }

        for scalar in host.unicodeScalars {
            guard isASCIILetterOrDigit(scalar) || scalar == "-" || scalar == "." else {
                return false
            }
        }

        return true
    }

    private static func isASCIILetterOrDigit(_ scalar: UnicodeScalar) -> Bool {
        (65 ... 90).contains(Int(scalar.value))
            || (97 ... 122).contains(Int(scalar.value))
            || (48 ... 57).contains(Int(scalar.value))
    }

    private static func isContinuationCharacter(
        _ utf16Value: unichar,
        after currentQuery: String
    ) -> Bool {
        guard let scalar = UnicodeScalar(Int(utf16Value)) else { return false }

        let parts = currentQuery.split(separator: "@", omittingEmptySubsequences: false)
        if parts.count == 1 {
            if isASCIILetterOrDigit(scalar) || scalar == "_" || scalar == "-" {
                return true
            }
            return scalar == "@" && !currentQuery.isEmpty
        }

        guard parts.count == 2 else { return false }
        return isASCIILetterOrDigit(scalar) || scalar == "-" || scalar == "."
    }
}

enum ComposeMentionPanelPlacement {
    static let rowHeight: CGFloat = 62
    static let maximumListHeight: CGFloat = 248

    static func estimatedHeight(suggestionCount: Int) -> CGFloat {
        guard suggestionCount > 0 else { return 52 }
        return min(CGFloat(suggestionCount) * rowHeight, maximumListHeight)
    }

    static func width(in editorWidth: CGFloat) -> CGFloat {
        max(220, min(editorWidth, 380))
    }

    static func x(caretRect: CGRect, editorWidth: CGFloat) -> CGFloat {
        let panelWidth = width(in: editorWidth)
        let proposedX = caretRect.minX - 8
        return min(max(0, proposedX), max(0, editorWidth - panelWidth))
    }

    static func y(
        caretRect: CGRect,
        editorHeight: CGFloat,
        suggestionCount: Int
    ) -> CGFloat {
        let proposedY = caretRect.maxY + 14
        let estimatedHeight = estimatedHeight(suggestionCount: suggestionCount)
        let maxY = max(8, editorHeight - estimatedHeight - 8)
        return min(max(8, proposedY), maxY)
    }
}

private extension CharacterSet {
    func containsUnicodeScalar(_ utf16Value: unichar) -> Bool {
        guard let scalar = UnicodeScalar(Int(utf16Value)) else { return false }
        return contains(scalar)
    }
}
