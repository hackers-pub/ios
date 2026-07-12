import Foundation
@testable import HackersPub
import Testing

struct DeepLinkRouterTests {
    @Test func customSchemePreservesAuthorityUsernameAndHost() throws {
        let url = try #require(URL(string: "hackerspub://@Jane@example.com"))

        #expect(HackersPubURLRouter.resolve(url) == .profile(handle: "Jane@example.com"))
    }

    @Test func customSchemePreservesEncodedAndUnicodeAuthorityHandles() throws {
        let cases: [(String, String)] = [
            ("hackerspub://%40Jane@example.com", "Jane@example.com"),
            ("hackerspub://@제인@example.com", "제인@example.com"),
            ("hackerspub://%40J%C3%A4ne@example.com", "Jäne@example.com"),
            ("hackerspub://%40J%C3%A4ne@例え.テスト", "Jäne@例え.テスト"),
            ("hackerspub://%40Jane@example%2540literal.com", "Jane@example%40literal.com")
        ]

        for (rawURL, expectedHandle) in cases {
            let url = try #require(URL(string: rawURL))

            #expect(
                HackersPubURLRouter.resolve(url) == .profile(handle: expectedHandle),
                "Expected valid profile authority for \(rawURL)"
            )
        }
    }

    @Test func customSchemeExcludesPortFromHandleDomain() throws {
        let url = try #require(URL(string: "hackerspub://%40Jane@example.com:8443"))

        #expect(HackersPubURLRouter.resolve(url) == .profile(handle: "Jane@example.com"))
    }

    @Test func rejectsEncodedHostDelimitersAndControlsWithoutPathFallback() throws {
        let malformedURLs = [
            "hackerspub://%40john@example%40evil.com",
            "hackerspub://%40john@example%40evil.com/tags/swift",
            "hackerspub://%40john@example%3Aevil.com",
            "hackerspub://%40john@example%2Fevil.com",
            "hackerspub://%40john@example%3Fevil.com",
            "hackerspub://%40john@example%23evil.com",
            "hackerspub://%40john@example%5Cevil.com",
            "hackerspub://%40john@example%20evil.com",
            "hackerspub://%40john@example%09evil.com",
            "hackerspub://%40john@example%0Aevil.com",
            "hackerspub://%40john@example%00evil.com"
        ]

        for rawURL in malformedURLs {
            let url = try #require(URL(string: rawURL))
            let components = try #require(
                URLComponents(url: url, resolvingAgainstBaseURL: false)
            )

            #expect(
                CustomSchemeAuthority(components: components) == nil,
                "Expected invalid decoded host for \(rawURL)"
            )
            #expect(
                HackersPubURLRouter.resolve(url) == nil,
                "Expected no path fallback for \(rawURL)"
            )
        }
    }

    @Test func rejectsMalformedCustomSchemeAuthoritiesWithoutPathFallback() throws {
        let malformedURLs = [
            "hackerspub://@example.com",
            "hackerspub://%40@example.com",
            "hackerspub://@@example.com",
            "hackerspub://@john@@example.com",
            "hackerspub://@/tags/swift",
            "hackerspub://%ZZ@example.com"
        ]

        for rawURL in malformedURLs {
            let url = try #require(URL(string: rawURL))

            #expect(
                HackersPubURLRouter.resolve(url) == nil,
                "Expected malformed authority to be rejected for \(rawURL)"
            )
        }
    }

    @Test func decodesPercentEncodedPathSegmentsExactlyOnce() throws {
        let url = try #require(URL(string: "https://hackers.pub/tags/100%2525"))

        #expect(HackersPubURLRouter.resolve(url) == .tagSearch("100%25"))
    }

    @Test func preservesEncodedSlashInsideOnePathSegment() throws {
        let url = try #require(URL(string: "https://hackers.pub/tags/swift%2Fui"))

        #expect(HackersPubURLRouter.resolve(url) == .tagSearch("swift/ui"))
    }

    @Test func preservesLiteralPercentThatIsNotAnEscapeAfterDecoding() throws {
        let url = try #require(URL(string: "https://hackers.pub/tags/%25ZZ"))

        #expect(HackersPubURLRouter.resolve(url) == .tagSearch("%ZZ"))
    }

    @Test func acceptsWWWHostAndNormalizesOnlyStructuralKeywords() throws {
        let url = try #require(URL(string: "https://WWW.HACKERS.PUB/TaGs/MiXeD"))

        #expect(HackersPubURLRouter.resolve(url) == .tagSearch("MiXeD"))
    }

    @Test func acceptsDefaultHTTPSPortForSupportedHosts() throws {
        let urls = try [
            #require(URL(string: "https://hackers.pub/tags/swift")),
            #require(URL(string: "https://hackers.pub:443/tags/swift")),
            #require(URL(string: "https://www.hackers.pub/tags/swift")),
            #require(URL(string: "https://www.hackers.pub:443/tags/swift"))
        ]

        for url in urls {
            #expect(HackersPubURLRouter.resolve(url) == .tagSearch("swift"))
            #expect(HackersPubURLRouter.isHackersPubWebURL(url))
        }
    }

    @Test func rejectsNonstandardHTTPSPortsForSupportedHosts() throws {
        let urls = try [
            #require(URL(string: "https://hackers.pub:444/tags/swift")),
            #require(URL(string: "https://www.hackers.pub:8443/tags/swift"))
        ]

        for url in urls {
            #expect(HackersPubURLRouter.resolve(url) == nil)
            #expect(!HackersPubURLRouter.isHackersPubWebURL(url))
        }
    }

    @Test func acceptsDefaultHTTPPortForSupportedHosts() throws {
        let urls = try [
            #require(URL(string: "http://hackers.pub/tags/swift")),
            #require(URL(string: "http://hackers.pub:80/tags/swift")),
            #require(URL(string: "http://www.hackers.pub/tags/swift")),
            #require(URL(string: "http://www.hackers.pub:80/tags/swift"))
        ]

        for url in urls {
            #expect(HackersPubURLRouter.resolve(url) == .tagSearch("swift"))
            #expect(HackersPubURLRouter.isHackersPubWebURL(url))
        }
    }

    @Test func rejectsNonstandardHTTPPortsForSupportedHosts() throws {
        let urls = try [
            #require(URL(string: "http://hackers.pub:81/tags/swift")),
            #require(URL(string: "http://www.hackers.pub:8080/tags/swift"))
        ]

        for url in urls {
            #expect(HackersPubURLRouter.resolve(url) == nil)
            #expect(!HackersPubURLRouter.isHackersPubWebURL(url))
        }
    }

    @Test func acceptsCustomSchemeCommandsCaseInsensitivelyWithoutChangingPayload() throws {
        let url = try #require(URL(string: "HACKERSPUB://TaGs/MiXeD"))

        #expect(HackersPubURLRouter.resolve(url) == .tagSearch("MiXeD"))
    }

    @Test func rejectsForeignSubdomains() throws {
        let urls = try [
            #require(URL(string: "https://evil.hackers.pub/tags/swift")),
            #require(URL(string: "https://hackers.pub.evil.example/tags/swift")),
            #require(URL(string: "https://www.hackers.pub.evil.example/tags/swift"))
        ]

        for url in urls {
            #expect(HackersPubURLRouter.resolve(url) == nil)
            #expect(!HackersPubURLRouter.isHackersPubWebURL(url))
        }
    }

    @Test func associatedDomainsOnlyClaimOriginsWithDirectAASADeployment() throws {
        let entitlementsURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("HackersPub/HackersPub.entitlements")
        let data = try Data(contentsOf: entitlementsURL)
        let propertyList = try PropertyListSerialization.propertyList(from: data, format: nil)
        let entitlements = try #require(propertyList as? [String: Any])
        let domains = try #require(
            entitlements["com.apple.developer.associated-domains"] as? [String]
        )

        let appLinkDomains = Set(domains.filter { $0.hasPrefix("applinks:") })

        #expect(appLinkDomains == [
            "applinks:hackers.pub",
            "applinks:hackers.pub?mode=developer"
        ])
    }

    @Test func acceptsUppercaseUUIDRouteWithoutChangingItsPayload() throws {
        let id = "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"
        let url = try #require(URL(string: "https://hackers.pub/news/\(id)"))

        #expect(HackersPubURLRouter.resolve(url) == .newsStory(id: id))
    }
}
