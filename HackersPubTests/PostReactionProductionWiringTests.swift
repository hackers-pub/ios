import Foundation
import Testing

struct PostReactionProductionWiringTests {
    @Test func reactionSelectionUsesOneScopedReconciliationPathInBothViews() throws {
        for source in try postReactionSources() {
            let toggleReaction = try #require(source.block(after: "private func toggleReaction("))
            let synchronize = try #require(source.block(after: "private func synchronizeReactionMutation("))
            let picker = try #require(source.block(after: "onEmojiSelect: { emoji in"))

            #expect(source.contains("reactionInfoState.cancel()"))
            #expect(source.contains("PostReactionRequestCoordinator"))
            #expect(toggleReaction.contains("beginMutation()"))
            #expect(!toggleReaction.contains("refreshPost()"))
            #expect(synchronize.contains("await fetchReactionInfos()"))
            #expect(picker.contains("if let result = await toggleReaction(emoji: emoji)"))
            #expect(picker.contains("await synchronizeReactionMutation(result)"))
            #expect(!picker.contains("await refreshPost()"))
        }
    }

    private func postReactionSources() throws -> [String] {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try [
            "HackersPub/Views/PostView.swift",
            "HackersPub/Views/PostDetailView.swift"
        ].map {
            try String(
                contentsOf: repositoryRoot.appendingPathComponent($0),
                encoding: .utf8
            )
        }
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
