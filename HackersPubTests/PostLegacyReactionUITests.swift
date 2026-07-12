import Foundation
import Testing

struct PostLegacyReactionUITests {
    @Test func postViewsNoLongerDeclareSupersededReactionCardsOrStats() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let detailSource = try String(
            contentsOf: repositoryRoot
                .appendingPathComponent("HackersPub/Views/PostDetailView.swift"),
            encoding: .utf8
        )
        let postSource = try String(
            contentsOf: repositoryRoot
                .appendingPathComponent("HackersPub/Views/PostView.swift"),
            encoding: .utf8
        )

        #expect(!detailSource.contains("struct StatView"))
        #expect(!detailSource.contains("struct ReactionGroupView"))
        #expect(!detailSource.contains("reactionGroupInfo(from:"))
        #expect(!postSource.contains("reactionGroupInfo(from:"))
    }
}
