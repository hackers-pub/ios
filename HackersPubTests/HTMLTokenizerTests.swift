@testable import HackersPub
import Testing

struct HTMLTokenizerTests {
    @Test func tokenizerHasNoUnreachableThrowingPath() {
        let tokenize: (String) -> [HTMLToken] = HTMLTokenizer.tokenize

        #expect(tokenize("<p>safe</p>") == [
            .openTag(raw: "<p>", name: "p"),
            .text("safe"),
            .closeTag(raw: "</p>", name: "p")
        ])
    }

    @Test func commentIsConsumedAndNotExposedAsAToken() {
        let tokens = HTMLTokenizer.tokenize("<p>A<!-- <script> -->B</p><p>rest</p>")

        #expect(tokens == [
            .openTag(raw: "<p>", name: "p"),
            .text("A"),
            .text("B"),
            .closeTag(raw: "</p>", name: "p"),
            .openTag(raw: "<p>", name: "p"),
            .text("rest"),
            .closeTag(raw: "</p>", name: "p")
        ])
    }

    @Test func declarationProcessingInstructionAndCDATAAreConsumedWithoutTokens() {
        let tokens = HTMLTokenizer.tokenize(
            "<!DOCTYPE html><?xml version=\"1.0\"?><![CDATA[<script>ignored</script>]]><p>Visible</p>"
        )

        #expect(tokens == [
            .openTag(raw: "<p>", name: "p"),
            .text("Visible"),
            .closeTag(raw: "</p>", name: "p")
        ])
    }

    @Test func pseudoTagWithoutASCIILetterIsTokenizedAsText() {
        let tokens = HTMLTokenizer.tokenize("I <3 Swift> forever")

        #expect(tokens == [
            .text("I "),
            .text("<"),
            .text("3 Swift> forever")
        ])
    }

    @Test func unterminatedUnsafeCloseIsConsumedWithUnsafeContent() {
        let tokens = HTMLTokenizer.tokenize("<p>Hi</p><script>x</script")

        #expect(tokens == [
            .openTag(raw: "<p>", name: "p"),
            .text("Hi"),
            .closeTag(raw: "</p>", name: "p"),
            .openTag(raw: "<script>", name: "script"),
            .unsafeContent(raw: "x", name: "script")
        ])
    }

    @Test func unterminatedUnsafeOpenIsConsumedWithoutAToken() {
        let tokens = HTMLTokenizer.tokenize("<p>Hi</p><style")

        #expect(tokens == [
            .openTag(raw: "<p>", name: "p"),
            .text("Hi"),
            .closeTag(raw: "</p>", name: "p")
        ])
    }

    @Test func imageFormsAreVoidTagsEvenWhenAttributesContainGreaterThan() {
        let tokens = HTMLTokenizer.tokenize("<p><img alt=\"a>b\" src=\"u.jpg\"><img><img/></p>")

        #expect(tokens == [
            .openTag(raw: "<p>", name: "p"),
            .voidTag(raw: "<img alt=\"a>b\" src=\"u.jpg\">", name: "img"),
            .voidTag(raw: "<img>", name: "img"),
            .voidTag(raw: "<img/>", name: "img"),
            .closeTag(raw: "</p>", name: "p")
        ])
    }
}
