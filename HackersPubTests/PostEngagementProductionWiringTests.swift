import Foundation
import Testing

struct PostEngagementProductionWiringTests {
    @Test func postAndDetailViewsUseSharedDisplayedPostEngagementState() throws {
        let postView = try source(named: "HackersPub/Views/PostView.swift")
        let detailView = try source(named: "HackersPub/Views/PostDetailView.swift")

        #expect(postView.contains("@State private var engagementState: PostEngagementState"))
        #expect(postView.contains("PostEngagementState(post: post)"))
        #expect(postView.contains("private var engagementTargetID: String"))
        #expect(postView.contains("postID: engagementTargetID"))
        #expect(postView.contains("replyToPostId: engagementTargetID"))
        #expect(postView.contains("quotedPostId: engagementTargetID"))
        #expect(postView.contains("PostDetailView(postId: engagementTargetID)"))

        #expect(detailView.contains("@State private var engagementState: PostEngagementState?"))
        #expect(detailView.contains("reconcileEngagementState(with: fetchedPost)"))
        #expect(detailView.contains("private var engagementTargetID: String"))
        #expect(detailView.contains("postID: engagementTargetID"))
        #expect(detailView.contains("replyToPostId: engagementTargetID"))
        #expect(detailView.contains("quotedPostId: engagementTargetID"))
    }

    private func source(named relativePath: String) throws -> String {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(
            contentsOf: repositoryRoot.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }
}
