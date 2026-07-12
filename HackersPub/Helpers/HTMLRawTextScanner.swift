import Foundation

enum HTMLRawTextScanner {
    static func indexAfterClosingTag(
        named name: String,
        in html: String,
        from start: String.Index
    ) -> String.Index? {
        var searchIndex = start

        while searchIndex < html.endIndex {
            guard let candidate = html[searchIndex...].firstIndex(of: "<") else { break }

            if matchesClosingTagName(named: name, in: html, at: candidate) {
                if let tagEnd = html[candidate...].firstIndex(of: ">") {
                    return html.index(after: tagEnd)
                }
            }

            searchIndex = html.index(after: candidate)
        }

        return nil
    }

    private static func matchesClosingTagName(
        named name: String,
        in html: String,
        at candidate: String.Index
    ) -> Bool {
        var index = html.index(after: candidate)
        guard index < html.endIndex, html[index] == "/" else { return false }
        index = html.index(after: index)

        for expectedByte in name.utf8 {
            guard index < html.endIndex,
                  matchesASCIICaseInsensitive(html[index], expectedByte: expectedByte)
            else {
                return false
            }
            index = html.index(after: index)
        }

        guard index < html.endIndex else { return false }
        let boundary = html[index]
        return boundary == ">" || boundary == "/" || boundary.isHTMLSpace
    }

    private static func matchesASCIICaseInsensitive(
        _ character: Character,
        expectedByte: UInt8
    ) -> Bool {
        guard character.unicodeScalars.count == 1,
              let scalar = character.unicodeScalars.first,
              scalar.value < 128
        else {
            return false
        }

        let actualByte = UInt8(scalar.value)
        return lowercaseASCII(actualByte) == lowercaseASCII(expectedByte)
    }

    private static func lowercaseASCII(_ byte: UInt8) -> UInt8 {
        (65 ... 90).contains(byte) ? byte + 32 : byte
    }
}

private extension Character {
    var isHTMLSpace: Bool {
        self == "\t" || self == "\n" || self == "\u{000C}" || self == "\r" || self == " "
    }
}
