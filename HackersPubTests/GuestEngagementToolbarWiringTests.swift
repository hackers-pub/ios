import Foundation
@testable import HackersPub
import Testing

struct GuestEngagementToolbarWiringTests {
    @Test func postAndDetailToolbarsExposePublicReplyAndShareControls() throws {
        for source in try toolbarSources() {
            let controls = try toolbarControls(in: source)

            #expect(controls.contains("icon: \"arrowshape.turn.up.left\""))
            #expect(controls.contains("icon: \"arrow.2.squarepath\""))
            #expect(controls.contains("handleShareTap()"))
            #expect(controls.contains("handleShareLongPress()"))
            #expect(firstToolbarControl(in: controls) == "EngagementToolbarButton(")

            #expect(source.contains("performShareAccessAction(isAlternateAction: false)"))
            #expect(source.contains("performShareAccessAction(isAlternateAction: true)"))
        }
    }

    @Test func guestShareGesturesAlwaysResolveToThePublicSharesRoute() {
        for actionsSwapped in [false, true] {
            for isAlternateAction in [false, true] {
                #expect(
                    PostEngagementAccessPolicy.share(
                        isAuthenticated: false,
                        actionsSwapped: actionsSwapped,
                        isAlternateAction: isAlternateAction,
                        postID: "post"
                    ) == .viewShares(postID: "post")
                )
            }
        }
    }

    @Test func authenticatedShareGesturesRetainTheirConfiguredToggleAndPublicRoutes() {
        #expect(
            PostEngagementAccessPolicy.share(
                isAuthenticated: true,
                actionsSwapped: false,
                isAlternateAction: false,
                postID: "post"
            ) == .toggleShare(postID: "post")
        )
        #expect(
            PostEngagementAccessPolicy.share(
                isAuthenticated: true,
                actionsSwapped: false,
                isAlternateAction: true,
                postID: "post"
            ) == .viewShares(postID: "post")
        )
    }

    private func toolbarSources() throws -> [String] {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        return try ["PostView.swift", "PostDetailView.swift"].map { name in
            try String(
                contentsOf: root.appending(path: "HackersPub/Views/\(name)"),
                encoding: .utf8
            )
        }
    }

    private func toolbarControls(in source: String) throws -> String {
        let share = try #require(source.range(of: "icon: \"arrow.2.squarepath\""))
        let prefix = source[..<share.lowerBound]
        let toolbarStart = try #require(prefix.range(of: "HStack(spacing: 16)", options: .backwards))
        let reaction = try #require(
            source.range(of: "icon: viewerHasReacted", range: share.upperBound ..< source.endIndex)
        )

        return String(source[toolbarStart.lowerBound ..< reaction.lowerBound])
    }

    private func firstToolbarControl(in controls: String) -> String {
        controls
            .split(separator: "\n")
            .dropFirst()
            .first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            ?? ""
    }
}
