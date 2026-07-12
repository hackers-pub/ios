import Foundation
@testable import HackersPub
import Testing

struct DeepLinkURLCanonicalizerTests {
    @Test func canonicalizesDefaultHTTPSAndHTTPPortsBeforePostComparison() {
        let httpsURL = "https://HACKERS.PUB:443/@alice/2026/article/#fragment"
        let httpURL = "http://hackers.pub:80/@alice/2026/article/"

        #expect(
            DeepLinkURLCanonicalizer.normalizedURLString(httpsURL) ==
                "https://hackers.pub/@alice/2026/article"
        )
        #expect(
            DeepLinkURLCanonicalizer.normalizedURLString(httpURL) ==
                "http://hackers.pub/@alice/2026/article"
        )
    }

    @Test func preservesNondefaultPortsAndRouterRejectsTheirPostAndArticleRoutes() throws {
        let noteURL = try #require(
            URL(string: "https://hackers.pub:8443/@alice/AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")
        )
        let articleURL = try #require(URL(string: "http://hackers.pub:8080/@alice/2026/article"))

        #expect(HackersPubURLRouter.resolve(noteURL) == nil)
        #expect(HackersPubURLRouter.resolve(articleURL) == nil)
        #expect(
            DeepLinkURLCanonicalizer.normalizedURLString(noteURL.absoluteString) ==
                noteURL.absoluteString
        )
        #expect(
            DeepLinkURLCanonicalizer.normalizedURLString(articleURL.absoluteString) ==
                articleURL.absoluteString
        )
    }

    @Test func routerAcceptsDefaultPortNoteAndArticleRoutes() throws {
        let noteURL = try #require(
            URL(string: "https://hackers.pub:443/@alice/AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")
        )
        let articleURL = try #require(URL(string: "http://hackers.pub:80/@alice/2026/article"))

        #expect(HackersPubURLRouter.resolve(noteURL) == .postURL(noteURL.absoluteString))
        #expect(HackersPubURLRouter.resolve(articleURL) == .postURL(articleURL.absoluteString))
    }
}
