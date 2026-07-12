import Foundation
import Testing

struct PostEngagementLocalizationTests {
    @Test func postEngagementViewsUseLocalizedCopyWithEnglishAndKoreanParity() throws {
        let postView = try source(named: "HackersPub/Views/PostView.swift")
        let detailView = try source(named: "HackersPub/Views/PostDetailView.swift")
        let sheets = try source(named: "HackersPub/Views/PostEngagementSheets.swift")
        let english = try source(named: "HackersPub/en.lproj/Localizable.strings")
        let korean = try source(named: "HackersPub/ko.lproj/Localizable.strings")

        #expect(postView.contains("Text(PostL10n.reposted)"))
        #expect(postView.contains("Label(PostL10n.shareAction"))
        #expect(detailView.contains("Text(PostL10n.replyingTo)"))
        #expect(detailView.contains("Text(PostL10n.repliesTitle)"))
        #expect(detailView.contains("Button(PostL10n.loadMoreReplies)"))
        #expect(detailView.contains(".navigationTitle(PostL10n.postTitle)"))
        #expect(sheets.contains("PostEngagementSheetL10n.sharesEmpty"))
        #expect(sheets.contains("PostEngagementSheetL10n.quotesEmpty"))

        for key in [
            "post.title",
            "post.reposted",
            "post.replyingTo",
            "post.replies.title",
            "post.replies.loadMore",
            "post.share.action",
            "engagement.shares.empty",
            "engagement.shares.loadMore",
            "engagement.quotes.empty",
            "engagement.quotes.loadMore"
        ] {
            #expect(english.contains("\"\(key)\""))
            #expect(korean.contains("\"\(key)\""))
        }
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
