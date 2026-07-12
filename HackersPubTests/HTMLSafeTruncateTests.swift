@testable import HackersPub
import Testing

// swiftlint:disable:next type_body_length
struct HTMLSafeTruncateTests {
    // MARK: - Basic Truncation

    @Test func plainTextTruncation() {
        let html = "Hello, World!"
        let result = html.htmlTruncated(limit: 5)
        #expect(result == "Hello\u{2026}")
    }

    @Test func noTruncationWhenUnderLimit() {
        let html = "Short"
        let result = html.htmlTruncated(limit: 100)
        #expect(result == "Short")
    }

    @Test func exactLimitReturnsOriginal() {
        let html = "12345"
        let result = html.htmlTruncated(limit: 5)
        #expect(result == "12345")
    }

    @Test func emptyStringReturnsEmpty() {
        let result = "".htmlTruncated(limit: 10)
        #expect(result == "")
    }

    @Test func zeroLimitReturnsEmpty() {
        let result = "Hello".htmlTruncated(limit: 0)
        #expect(result == "")
    }

    // MARK: - Nested Tags

    @Test func nestedTagsAreClosedProperly() {
        let html = "<p><strong><em>Hello, World!</em></strong></p>"
        let result = html.htmlTruncated(limit: 5)
        #expect(result == "<p><strong><em>Hello\u{2026}</em></strong></p>")
    }

    @Test func nestedTagsNoTruncation() {
        let html = "<p><strong>Hi</strong></p>"
        let result = html.htmlTruncated(limit: 100)
        #expect(result == "<p><strong>Hi</strong></p>")
    }

    @Test func multipleParagraphs() {
        let html = "<p>First paragraph</p><p>Second paragraph</p>"
        let result = html.htmlTruncated(limit: 10)
        #expect(result == "<p>First para\u{2026}</p>")
    }

    // MARK: - Links

    @Test func linkTagPreserved() {
        let html = #"<a href="https://example.com">Click here</a>"#
        let result = html.htmlTruncated(limit: 5)
        #expect(result == #"<a href="https://example.com">Click\#u{2026}</a>"#)
    }

    @Test func linkInsideNestedTags() {
        let html = #"<p>Visit <a href="https://example.com">our website</a> today</p>"#
        let result = html.htmlTruncated(limit: 12)
        #expect(result == #"<p>Visit <a href="https://example.com">our we\#u{2026}</a></p>"#)
    }

    // MARK: - Void Tags (img, br, hr)

    @Test func brTagPreserved() {
        let html = "Hello<br>World"
        let result = html.htmlTruncated(limit: 8)
        #expect(result == "Hello<br>Wor\u{2026}")
    }

    @Test func hrTagPreserved() {
        let html = "Before<hr>After"
        let result = html.htmlTruncated(limit: 8)
        #expect(result == "Before<hr>Af\u{2026}")
    }

    @Test func imgTagStrippedByDefault() {
        let html = #"<p>Text <img src="photo.jpg"> more text</p>"#
        let result = html.htmlTruncated(limit: 100)
        #expect(!result.contains("<img"))
    }

    @Test func imgTagKeptWhenRequested() {
        let html = #"<p>Text <img src="photo.jpg"> more text</p>"#
        let result = html.htmlTruncated(
            limit: 100,
            options: HTMLTruncateOptions(keepImageTag: true)
        )
        #expect(result.contains("<img"))
    }

    @Test func imageWithQuotedGreaterThanIsRemovedWithoutAttributeResidue() {
        let html = #"<p>x<img alt="a>b" src="u.jpg">y</p>"#
        let result = html.htmlTruncated(limit: 100)

        #expect(result == "<p>xy</p>")
    }

    @Test func bareAndSelfClosingImageTagsAreRemovedByDefault() {
        let result = "<p>a<img>b<img/>c</p>".htmlTruncated(limit: 100)

        #expect(result == "<p>abc</p>")
    }

    @Test func keepImageTagIsAppliedWhileBuildingTruncatedOutput() {
        let html = #"<p><img alt="a>b" src="u.jpg">abc</p>"#
        let withoutImages = html.htmlTruncated(limit: 1)
        let withImages = html.htmlTruncated(
            limit: 1,
            options: HTMLTruncateOptions(keepImageTag: true)
        )

        #expect(withoutImages == "<p>a\u{2026}</p>")
        #expect(withImages == #"<p><img alt="a>b" src="u.jpg">a\#u{2026}</p>"#)
    }

    @Test func selfClosingBrTag() {
        let html = "Line1<br/>Line2"
        let result = html.htmlTruncated(limit: 8)
        #expect(result == "Line1<br/>Lin\u{2026}")
    }

    // MARK: - HTML Entities

    @Test func ampEntityCountsAsOneCharacter() {
        let html = "A&amp;B"
        let result = html.htmlTruncated(limit: 2)
        #expect(result == "A&amp;\u{2026}")
    }

    @Test func ltEntityCountsAsOneCharacter() {
        let html = "&lt;tag&gt;"
        let result = html.htmlTruncated(limit: 2)
        #expect(result == "&lt;t\u{2026}")
    }

    @Test func numericEntitySafety() {
        let html = "A&#x27;B"
        let result = html.htmlTruncated(limit: 2)
        #expect(result == "A&#x27;\u{2026}")
    }

    @Test func entityNotSplitInMiddle() {
        // The entity &amp; should either be fully included or not included at all.
        let html = "&amp;test"
        let result = html.htmlTruncated(limit: 1)
        #expect(result == "&amp;\u{2026}")
    }

    @Test func multipleEntitiesInSequence() {
        let html = "&lt;&gt;&amp;"
        let result = html.htmlTruncated(limit: 2)
        #expect(result == "&lt;&gt;\u{2026}")
    }

    // MARK: - Emoji / Korean / Unicode

    @Test func emojiCountsAsOneCharacter() {
        let html = "Hi \u{1F44B}\u{1F3FB} there"
        // "Hi 👋🏻 there" - 👋🏻 is a single grapheme cluster
        let result = html.htmlTruncated(limit: 4)
        #expect(result == "Hi \u{1F44B}\u{1F3FB}\u{2026}")
    }

    @Test func koreanTextTruncation() {
        let html = "안녕하세요 반갑습니다"
        let result = html.htmlTruncated(limit: 5)
        #expect(result == "안녕하세요\u{2026}")
    }

    @Test func mixedEmojiAndText() {
        let html = "<p>Hello 🌍🌎🌏</p>"
        let result = html.htmlTruncated(limit: 8)
        #expect(result == "<p>Hello 🌍🌎\u{2026}</p>")
    }

    @Test func familyEmojiNotSplit() {
        // 👨‍👩‍👧‍👦 is a single grapheme cluster (ZWJ sequence)
        let html = "A\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}\u{200D}\u{1F466}B"
        let result = html.htmlTruncated(limit: 2)
        #expect(result == "A\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}\u{200D}\u{1F466}\u{2026}")
    }

    // MARK: - Malformed HTML

    @Test func unclosedTagGetsClosedAutomatically() {
        let html = "<p><strong>Hello World"
        let result = html.htmlTruncated(limit: 5)
        #expect(result == "<p><strong>Hello\u{2026}</strong></p>")
    }

    @Test func extraCloseTagIgnored() {
        let html = "<p>Hello</p></div>"
        let result = html.htmlTruncated(limit: 100)
        #expect(result == "<p>Hello</p></div>")
    }

    @Test func misnested_tags() {
        // <b><i>Hello</b></i> – the close tag order is wrong
        let html = "<b><i>Hello World</i></b>"
        let result = html.htmlTruncated(limit: 5)
        #expect(result == "<b><i>Hello\u{2026}</i></b>")
    }

    // MARK: - Code / Pre Blocks

    @Test func codeBlockTruncation() {
        let html = "<pre><code>let x = 42\nprint(x)</code></pre>"
        let result = html.htmlTruncated(limit: 10)
        #expect(result.hasPrefix("<pre><code>"))
        #expect(result.hasSuffix("</code></pre>"))
        #expect(result.contains("\u{2026}"))
    }

    @Test func inlineCodeTruncation() {
        let html = "Use <code>swift build</code> to compile"
        let result = html.htmlTruncated(limit: 15)
        #expect(result.contains("<code>"))
        #expect(result.contains("</code>"))
    }

    // MARK: - Script / Style Safety

    @Test func scriptTagContentIsStripped() {
        let html = "<p>Hello</p><script>alert('xss')</script><p>World</p>"
        let result = html.htmlTruncated(limit: 100)
        #expect(!result.contains("alert"))
        #expect(!result.contains("<script>"))
    }

    @Test func styleTagContentIsStripped() {
        let html = "<style>body { color: red; }</style><p>Hello World</p>"
        let result = html.htmlTruncated(limit: 100)
        #expect(!result.contains("<style>"))
        #expect(!result.contains("color: red"))
    }

    // MARK: - Ignored Markup and Malformed Unsafe Tags

    @Test func commentDoesNotConsumeVisibleLengthOrRetokenizeItsContents() {
        let html = "<p>A<!-- <script> -->B</p><p>rest of post</p>"
        let result = html.htmlTruncated(limit: 100)

        #expect(result == "<p>AB</p><p>rest of post</p>")
    }

    @Test func declarationsProcessingInstructionsAndCDATAAreNotRendered() {
        let html = "<!DOCTYPE html><?xml version=\"1.0\"?><![CDATA[hidden]]><p>RealText</p>"
        let result = html.htmlTruncated(limit: 8)

        #expect(result == "<p>RealText</p>")
    }

    @Test func ignoredMarkupDoesNotConsumeTruncationBudget() {
        let html = "<!-- abcdefghij --><p>RealText</p>"
        let result = html.htmlTruncated(limit: 8)

        #expect(result == "<p>RealText</p>")
    }

    @Test func pseudoTagWithoutASCIILetterRemainsVisibleText() {
        let result = "I <3 Swift> forever".htmlTruncated(limit: 4)

        #expect(result == "I <3\u{2026}")
        #expect(!result.contains("</3>"))
    }

    @Test func unterminatedUnsafeCloseFailsClosed() {
        let result = "<p>Hi</p><script>x</script".htmlTruncated(limit: 100)

        #expect(result == "<p>Hi</p>")
    }

    @Test func unterminatedUnsafeOpenFailsClosed() {
        let result = "<p>Hi</p><style".htmlTruncated(limit: 100)

        #expect(result == "<p>Hi</p>")
    }

    @Test func malformedUnsafeMarkupNeverFallsBackToOriginalHTML() {
        let html = "<script>alert('x')</script"
        let result = html.htmlTruncated(limit: 100)

        #expect(result == "")
    }

    // MARK: - Ellipsis Position

    @Test func ellipsisAppearsAfterTruncatedText() {
        let html = "<p>Long text that needs truncation</p>"
        let result = html.htmlTruncated(limit: 9)
        #expect(result == "<p>Long text\u{2026}</p>")
    }

    @Test func ellipsisBeforeClosingTags() {
        let html = "<div><p><em>Hello World</em></p></div>"
        let result = html.htmlTruncated(limit: 5)
        #expect(result == "<div><p><em>Hello\u{2026}</em></p></div>")
    }

    @Test func customEllipsis() {
        let html = "Hello World"
        let options = HTMLTruncateOptions(ellipsis: " [...]")
        let result = html.htmlTruncated(limit: 5, options: options)
        #expect(result == "Hello [...]")
    }

    @Test func readMoreIsEscapedAfterOpenFormattingTagsAreClosed() {
        let html = #"<p><strong><a href="https://example.com">Long linked text</a></strong></p>"#
        let options = HTMLTruncateOptions(readMoreText: "Read <more> & go")
        let result = html.htmlTruncated(limit: 4, options: options)

        #expect(
            result == #"<p><strong><a href="https://example.com">Long</a></strong></p>\#u{2026} <span>"#
                + HTMLReadMoreMarker.start
                + "Read &lt;more&gt; &amp; go"
                + HTMLReadMoreMarker.end
                + "</span>"
        )
    }

    @Test func mixedCaseClosingTagDoesNotLeaveAnExtraOpenTag() {
        let html = "<DIV>Hello</div><p>World more</p>"
        let result = html.htmlTruncated(limit: 9)

        #expect(result == "<DIV>Hello</div><p>Worl\u{2026}</p>")
    }

    @Test func noEllipsisWhenNotTruncated() {
        let html = "<p>Short</p>"
        let result = html.htmlTruncated(limit: 100)
        #expect(!result.contains("\u{2026}"))
    }

    // MARK: - Edge Cases

    @Test func onlyTagsNoText() {
        let html = "<div><br><hr></div>"
        let result = html.htmlTruncated(limit: 10)
        #expect(result == "<div><br><hr></div>")
    }

    @Test func deeplyNestedTags() {
        let html = "<div><section><article><p><span><strong><em>"
            + "Deep text here</em></strong></span></p></article></section></div>"
        let result = html.htmlTruncated(limit: 4)
        let expected = "<div><section><article><p><span><strong><em>"
            + "Deep\u{2026}</em></strong></span></p></article></section></div>"
        #expect(result == expected)
    }

    @Test func attributesWithSpecialCharsInValues() {
        let html = #"<a href="https://example.com?a=1&b=2" title="Click > here">Link text</a>"#
        let result = html.htmlTruncated(limit: 4)
        #expect(result.hasPrefix(#"<a href="https://example.com?a=1&b=2" title="Click > here">Link"#))
        #expect(result.hasSuffix("</a>"))
    }

    @Test func whitespacePreservation() {
        let html = "<p>  Hello  World  </p>"
        let result = html.htmlTruncated(limit: 8)
        #expect(result == "<p>  Hello \u{2026}</p>")
    }

    @Test func limitOfOneCharacter() {
        let html = "<p>Hello</p>"
        let result = html.htmlTruncated(limit: 1)
        #expect(result == "<p>H\u{2026}</p>")
    }

    @Test func consecutiveTags() {
        let html = "<b></b><i></i><p>Text</p>"
        let result = html.htmlTruncated(limit: 2)
        #expect(result == "<b></b><i></i><p>Te\u{2026}</p>")
    }
}
