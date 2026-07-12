import Foundation

/// Canonicalizes a URL supplied by WebKit without re-encoding its fragment.
/// Existing percent escapes are preserved exactly; malformed escapes are
/// rejected rather than silently turned into a different destination.
enum HTMLURLNormalizer {
    static func normalize(_ rawURL: String) -> URL? {
        let trimmed = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              containsOnlyValidPercentEscapes(trimmed),
              let components = URLComponents(string: trimmed),
              let scheme = components.scheme,
              !scheme.isEmpty,
              components.host?.isEmpty == false
        else {
            return nil
        }
        return components.url
    }

    private static func containsOnlyValidPercentEscapes(_ value: String) -> Bool {
        var index = value.startIndex
        while index < value.endIndex {
            guard value[index] == "%" else {
                index = value.index(after: index)
                continue
            }

            let first = value.index(after: index)
            guard first < value.endIndex else { return false }
            let second = value.index(after: first)
            guard second < value.endIndex,
                  value[first].isASCIIHexDigit,
                  value[second].isASCIIHexDigit
            else {
                return false
            }
            index = value.index(after: second)
        }
        return true
    }
}

private extension Character {
    var isASCIIHexDigit: Bool {
        ("0" ... "9").contains(self)
            || ("a" ... "f").contains(self)
            || ("A" ... "F").contains(self)
    }
}
