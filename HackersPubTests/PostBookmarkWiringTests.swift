import Foundation
@testable import HackersPub
import Testing

struct PostBookmarkWiringTests {
    @Test func postViewPublishesOnlyAuthoritativeBookmarkResults() throws {
        let source = try postViewSource()
        let toggleBookmark = try #require(source.block(after: "private func toggleBookmark()"))

        #expect(toggleBookmark.contains("PostBookmarkChangePropagation.resolve"))
        #expect(toggleBookmark.contains("postID: bookmarkTargetID"))
        #expect(toggleBookmark.contains("authoritativeState: payload.post.viewerHasBookmarked"))
        #expect(!toggleBookmark.contains("onBookmarkChanged?(bookmarkTargetID, previousState)"))
    }

    private func postViewSource() throws -> String {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = repositoryRoot
            .appendingPathComponent("HackersPub")
            .appendingPathComponent("Views")
            .appendingPathComponent("PostView.swift")
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }
}

private extension String {
    func block(after marker: String) -> String? {
        guard let markerRange = range(of: marker),
              let openingBrace = self[markerRange.upperBound...].firstIndex(of: "{")
        else {
            return nil
        }

        var depth = 0
        var index = openingBrace
        while index < endIndex {
            switch self[index] {
            case "{":
                depth += 1
            case "}":
                depth -= 1
                if depth == 0 {
                    return String(self[openingBrace ... index])
                }
            default:
                break
            }
            index = self.index(after: index)
        }
        return nil
    }
}
