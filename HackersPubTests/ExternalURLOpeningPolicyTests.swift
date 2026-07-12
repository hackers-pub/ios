import Foundation
@testable import HackersPub
import Testing

struct ExternalURLOpeningPolicyTests {
    @Test func ownedSchemeIsConsumedRegardlessOfCaseOrPayload() throws {
        let urls = try [
            #require(URL(string: "hackerspub://@alice")),
            #require(URL(string: "HACKERSPUB://unknown")),
            #require(URL(string: "hackerspub://%40john@example%40evil.com"))
        ]

        for url in urls {
            #expect(
                ExternalURLOpeningPolicy.action(for: url, useInAppBrowser: false) == .consumeOwnedScheme
            )
            #expect(
                ExternalURLOpeningPolicy.action(for: url, useInAppBrowser: true) == .consumeOwnedScheme
            )
        }
    }

    @Test func webURLsRespectBrowserPreferenceAndForcedInAppPresentation() throws {
        let url = try #require(URL(string: "https://example.com/path"))

        #expect(ExternalURLOpeningPolicy.action(for: url, useInAppBrowser: false) == .systemOpen)
        #expect(ExternalURLOpeningPolicy.action(for: url, useInAppBrowser: true) == .inAppBrowser)
        #expect(
            ExternalURLOpeningPolicy.action(
                for: url,
                useInAppBrowser: false,
                forceInAppBrowser: true
            ) == .inAppBrowser
        )
    }

    @Test func foreignCustomSchemesRemainSystemOwned() throws {
        let urls = try [
            #require(URL(string: "mailto:hello@example.com")),
            #require(URL(string: "tel:+15551234567")),
            #require(URL(string: "sms:+15551234567"))
        ]

        for url in urls {
            #expect(
                ExternalURLOpeningPolicy.action(for: url, useInAppBrowser: true) == .systemOpen
            )
        }
    }

    @Test func rendererWithoutNavigationCoordinatorConsumesOwnedURLs() throws {
        let url = try #require(URL(string: "hackerspub://unknown"))

        #expect(
            RendererLinkRoutingPolicy.action(
                for: url,
                hasNavigationCoordinator: false
            ) == .consumeOwnedScheme
        )
    }

    @Test func rendererWithNavigationCoordinatorRoutesOwnedURLsInternally() throws {
        let url = try #require(URL(string: "hackerspub://@alice"))

        #expect(
            RendererLinkRoutingPolicy.action(
                for: url,
                hasNavigationCoordinator: true
            ) == .deepLink
        )
    }

    @Test func rendererWithNavigationCoordinatorKeepsForeignCustomSchemesExternal() throws {
        let urls = try [
            #require(URL(string: "mailto:hello@example.com")),
            #require(URL(string: "tel:+15551234567")),
            #require(URL(string: "sms:+15551234567"))
        ]

        for url in urls {
            #expect(
                RendererLinkRoutingPolicy.action(
                    for: url,
                    hasNavigationCoordinator: true
                ) == .external
            )
        }
    }

    @Test func rendererWithNavigationCoordinatorPreservesWebRouting() throws {
        let urls = try [
            #require(URL(string: "https://hackers.pub/@alice")),
            #require(URL(string: "https://example.com/path"))
        ]

        for url in urls {
            #expect(
                RendererLinkRoutingPolicy.action(
                    for: url,
                    hasNavigationCoordinator: true
                ) == .deepLink
            )
        }
    }

    @Test func rendererWithoutNavigationCoordinatorPreservesWebAndForeignCustomDestinations() throws {
        let webURL = try #require(URL(string: "https://hackers.pub/@alice"))
        let foreignURL = try #require(URL(string: "mailto:hello@example.com"))

        #expect(
            RendererLinkRoutingPolicy.action(
                for: webURL,
                hasNavigationCoordinator: false
            ) == .inAppBrowser
        )
        #expect(
            RendererLinkRoutingPolicy.action(
                for: foreignURL,
                hasNavigationCoordinator: false
            ) == .external
        )
    }

    @Test func webViewNavigationPolicyCancelsOnlyOwnedSchemes() throws {
        let ownedURLs = try [
            #require(URL(string: "hackerspub://@alice")),
            #require(URL(string: "hackerspub://unknown")),
            #require(URL(string: "hackerspub://%40john@example%40evil.com"))
        ]
        let nonOwnedURLs = try [
            #require(URL(string: "https://example.com/path")),
            #require(URL(string: "mailto:hello@example.com"))
        ]

        for url in ownedURLs {
            #expect(RendererWebViewNavigationPolicy.action(for: url) == .cancel)
        }
        for url in nonOwnedURLs {
            #expect(RendererWebViewNavigationPolicy.action(for: url) == .allow)
        }
    }

    @Test func safariPreviewPolicyAllowsOnlyWebURLs() throws {
        let webURL = try #require(URL(string: "https://example.com/path"))
        let rejectedURLs = try [
            #require(URL(string: "hackerspub://@alice")),
            #require(URL(string: "hackerspub://unknown")),
            #require(URL(string: "mailto:hello@example.com")),
            #require(URL(string: "tel:+15551234567")),
            #require(URL(string: "sms:+15551234567"))
        ]

        #expect(SafariPreviewPolicy.url(for: webURL) == webURL)
        for url in rejectedURLs {
            #expect(SafariPreviewPolicy.url(for: url) == nil)
        }
    }
}
