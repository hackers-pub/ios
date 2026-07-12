@testable import HackersPub
import SwiftUI
import Testing
import UIKit

@MainActor
struct HTMLTextInteractionPolicyTests {
    @Test(arguments: [
        (HTMLContentRenderingContext.feedPreview, false),
        (HTMLContentRenderingContext.embeddedPreview, false),
        (HTMLContentRenderingContext.detail, true),
        (HTMLContentRenderingContext.document, true),
        (HTMLContentRenderingContext.profileBio, true)
    ])
    func selectionPolicyKeepsFeedLongPressSeparateFromDetailSelection(
        _ context: HTMLContentRenderingContext,
        _ expected: Bool
    ) {
        #expect(HTMLTextInteractionPolicy.allowsSelection(in: context) == expected)
    }

    @Test
    func selectableTextConfigurationIsNoneditableAndNonscrolling() {
        let textView = UITextView()
        HTMLTextInteractionPolicy.configure(textView, allowsSelection: true)

        #expect(!textView.isEditable)
        #expect(textView.isSelectable)
        #expect(!textView.isScrollEnabled)
        #expect(!textView.alwaysBounceVertical)
    }

    @Test
    func selectableCoordinatorRoutesOnlyTheDefaultLinkAction() throws {
        let router = ExternalURLRouter()
        router.useInAppBrowser = true
        var measuredHeight: CGFloat = 0
        let parent = SelectableHTMLTextView(
            html: "<a href=\"https://example.com/post\">post</a>",
            height: Binding(
                get: { measuredHeight },
                set: { measuredHeight = $0 }
            ),
            externalURLRouter: router
        )
        let coordinator = parent.makeCoordinator()
        let textView = UITextView()
        let url = try #require(URL(string: "https://example.com/post"))
        let range = NSRange(location: 0, length: 4)

        #expect(coordinator.textView(textView, shouldInteractWith: url, in: range, interaction: .presentActions))
        #expect(router.destination == nil)

        #expect(coordinator.textView(textView, shouldInteractWith: url, in: range, interaction: .preview))
        #expect(router.destination == nil)

        #expect(!coordinator.textView(textView, shouldInteractWith: url, in: range, interaction: .invokeDefaultAction))
        #expect(router.destination?.url == url)
    }
}
