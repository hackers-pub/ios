import Foundation
@testable import HackersPub
import Testing

struct ComposeMentionSupportTests {
    @Test func findsLocalAndFederatedMentionsAtTheCaret() {
        let local = ComposeMentionSupport.activeMention(
            in: "Hello @alice",
            selectedRange: NSRange(location: 12, length: 0)
        )
        let federated = ComposeMentionSupport.activeMention(
            in: "Hello @alice@example.com",
            selectedRange: NSRange(location: 24, length: 0)
        )

        #expect(local?.query == "alice")
        #expect(local?.range == NSRange(location: 6, length: 6))
        #expect(federated?.query == "alice@example.com")
        #expect(federated?.range == NSRange(location: 6, length: 18))
    }

    @Test func rejectsEmailLikeAndSelectedTextTriggers() {
        #expect(
            ComposeMentionSupport.activeMention(
                in: "mail@example",
                selectedRange: NSRange(location: 12, length: 0)
            ) == nil
        )
        #expect(
            ComposeMentionSupport.activeMention(
                in: "Hello @alice",
                selectedRange: NSRange(location: 12, length: 1)
            ) == nil
        )
    }

    @Test func replacementRangeConsumesExistingWhitespaceAfterTheMention() {
        let content = "Hi @alice   world"
        let mention = ComposeMentionMatch(
            query: "alice",
            range: NSRange(location: 3, length: 6)
        )

        let range = ComposeMentionSupport.replacementRange(
            in: content,
            mention: mention
        )

        #expect(range == NSRange(location: 3, length: 9))
    }
}
