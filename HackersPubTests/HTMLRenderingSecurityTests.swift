import Foundation
@testable import HackersPub
import Testing

private let expectedBlockquoteMarkup = [
    "<blockquote><p><em>Hello</em>",
    " <a href=\"https://example.com/post?q=one&amp;two\">link</a></p></blockquote>"
].joined()

private let expectedImageMarkup = [
    "<img src=\"https://cdn.example/image.jpg\" alt=\"A &quot;quoted&quot; image\"",
    " width=\"640\" height=\"480\">"
].joined()

private let videoMarkup = [
    "<video controls poster=\"https://cdn.example/poster.jpg\">",
    "<source src=\"https://cdn.example/movie.mp4\" type=\"video/mp4\"></video>"
].joined()

private let expectedTableMarkup = "<table><tr><th colspan=\"2\">Header</th></tr></table>"

struct HTMLRenderingSecurityTests {
    @Test
    func sanitizerRemovesExecutableAndNavigatingMarkup() {
        let input = """
        <p onclick="steal()">Safe <strong>text</strong></p>
        <script>window.webkit.messageHandlers.tapHandler.postMessage('spoof')</script>
        <a href="javascript:alert(1)" onmouseover="steal()">bad link</a>
        <iframe src="https://attacker.example"></iframe>
        <form action="https://attacker.example"><input name="token"></form>
        <base href="https://attacker.example/">
        <meta http-equiv="refresh" content="0;url=https://attacker.example">
        <img src="data:image/svg+xml,evil" onerror="steal()" alt="image">
        """

        let result = HTMLServerContentSanitizer.sanitize(input)

        #expect(result.contains("<p>Safe <strong>text</strong></p>"))
        #expect(result.contains("bad link"))
        #expect(result.contains("alt=\"image\""))
        #expect(!result.localizedCaseInsensitiveContains("script"))
        #expect(!result.localizedCaseInsensitiveContains("onclick"))
        #expect(!result.localizedCaseInsensitiveContains("onmouseover"))
        #expect(!result.localizedCaseInsensitiveContains("onerror"))
        #expect(!result.localizedCaseInsensitiveContains("javascript:"))
        #expect(!result.localizedCaseInsensitiveContains("iframe"))
        #expect(!result.localizedCaseInsensitiveContains("form"))
        #expect(!result.localizedCaseInsensitiveContains("base"))
        #expect(!result.localizedCaseInsensitiveContains("meta"))
        #expect(!result.localizedCaseInsensitiveContains("data:image"))
    }

    @Test
    func sanitizerPreservesFormattingAndHTTPSMedia() {
        let input = """
        <blockquote><p><em>Hello</em> <a href="https://example.com/post?q=one&amp;two">link</a></p></blockquote>
        <img src="https://cdn.example/image.jpg" alt="A &quot;quoted&quot; image" width="640" height="480">
        \(videoMarkup)
        <table><tr><th colspan="2">Header</th></tr></table>
        """

        let result = HTMLServerContentSanitizer.sanitize(input)

        #expect(result.contains(expectedBlockquoteMarkup))
        #expect(result.contains(expectedImageMarkup))
        #expect(result.contains(videoMarkup))
        #expect(result.contains(expectedTableMarkup))
    }

    @Test(arguments: [
        ("https://example.com/path", true),
        ("http://example.com/path", true),
        ("javascript:alert(1)", false),
        ("data:text/html,unsafe", false),
        ("file:///tmp/unsafe", false),
        ("blob:https://example.com/id", false),
        ("hackerspub://post/123", false)
    ])
    func sanitizerAllowsOnlyHTTPURLs(_ rawURL: String, _ isAllowed: Bool) {
        let result = HTMLServerContentSanitizer.sanitize("<a href=\"\(rawURL)\">link</a><img src=\"\(rawURL)\">")

        #expect(result.contains("href=") == isAllowed)
        #expect(result.contains("src=") == isAllowed)
    }

    @Test
    func sanitizerParsesQuotedAndUnquotedAbsoluteURLsWithoutTreatingPathSlashesAsTagSyntax() {
        let quotedURL = "https://cdn.example/assets/image.png?size=large/retina#hero"
        let unquotedURL = "http://cdn.example/assets/image.png?size%3Dcompact&inline#hero"
        let result = HTMLServerContentSanitizer.sanitize(
            "<a href=\"\(quotedURL)\">quoted</a><img src=\(unquotedURL) />"
        )

        #expect(result.contains("href=\"https://cdn.example/assets/image.png?size=large/retina#hero\""))
        #expect(result.contains("src=\"http://cdn.example/assets/image.png?size%3Dcompact&amp;inline#hero\""))
    }

    @Test
    func sanitizerKeepsValidSelfClosingMediaAndRejectsUnsafeUnquotedSchemes() {
        let result = HTMLServerContentSanitizer.sanitize(
            "<source src=https://cdn.example/media/movie.mp4?download#main />"
                + "<img src=data:image/svg+xml,evil />"
                + "<a href=javascript:alert(1)>unsafe</a>"
        )

        #expect(result.contains("<source src=\"https://cdn.example/media/movie.mp4?download#main\">"))
        #expect(!result.localizedCaseInsensitiveContains("data:image"))
        #expect(!result.localizedCaseInsensitiveContains("javascript:"))
    }

    @Test
    func sanitizerRequiresAnExactRawTextClosingTagNameBoundary() {
        let input = """
        <p>Before</p>
        <script>script hidden</ScRiPtUrE><p>still script hidden</p></SCRIPT>
        <p>Between</p>
        <style>style hidden</stylesheet><p>still style hidden</p></style>
        <p>After</p>
        """

        let result = HTMLServerContentSanitizer.sanitize(input)

        #expect(result.contains("<p>Before</p>"))
        #expect(result.contains("<p>Between</p>"))
        #expect(result.contains("<p>After</p>"))
        #expect(!result.contains("still script hidden"))
        #expect(!result.contains("still style hidden"))
    }

    @Test
    func navigationPolicyAllowsOnlyInitialDocumentAndUserActivatedHTTPLinks() throws {
        let aboutBlank = try #require(URL(string: "about:blank"))
        let httpsURL = try #require(URL(string: "https://example.com/post"))
        let customURL = try #require(URL(string: "hackerspub://post/123"))

        #expect(
            HTMLWebNavigationPolicy.decision(
                for: .init(url: aboutBlank, kind: .other, isMainFrame: true),
                allowsInitialDocumentLoad: true
            ) == .allowInitialDocument
        )
        #expect(
            HTMLWebNavigationPolicy.decision(
                for: .init(url: httpsURL, kind: .linkActivated, isMainFrame: true),
                allowsInitialDocumentLoad: false
            ) == .route(httpsURL)
        )

        for request in [
            HTMLWebNavigationRequest(url: httpsURL, kind: .other, isMainFrame: true),
            HTMLWebNavigationRequest(url: customURL, kind: .linkActivated, isMainFrame: true),
            HTMLWebNavigationRequest(url: aboutBlank, kind: .other, isMainFrame: true),
            HTMLWebNavigationRequest(url: nil, kind: .formSubmitted, isMainFrame: true),
            HTMLWebNavigationRequest(url: httpsURL, kind: .linkActivated, isMainFrame: false)
        ] {
            #expect(
                HTMLWebNavigationPolicy.decision(for: request, allowsInitialDocumentLoad: false) == .cancel
            )
        }
    }
}
