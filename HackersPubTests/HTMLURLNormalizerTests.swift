import Foundation
@testable import HackersPub
import Testing

struct HTMLURLNormalizerTests {
    @Test(arguments: [
        (
            "https://example.com/a%20b?query=one%20two#frag%20ment",
            "https://example.com/a%20b?query=one%20two#frag%20ment"
        ),
        (
            "https://example.com/한글?q=😀#조각",
            "https://example.com/%ED%95%9C%EA%B8%80?q=%F0%9F%98%80#%EC%A1%B0%EA%B0%81"
        ),
        ("https://example.com/a b?q=x y#frag z", "https://example.com/a%20b?q=x%20y#frag%20z"),
        (" https://example.com/p?q=a%2Bb&x=1#frag?z=2 ", "https://example.com/p?q=a%2Bb&x=1#frag?z=2")
    ])
    func normalizerPreservesExistingEscapesAndCanonicalizesUnicodeWhitespaceQueryAndFragment(
        _ raw: String,
        _ expected: String
    ) {
        #expect(HTMLURLNormalizer.normalize(raw)?.absoluteString == expected)
    }

    @Test(arguments: [
        "",
        "https://example.com/%zz",
        "https://example.com/%2",
        "not a URL",
        "https:///missing-host"
    ])
    func normalizerRejectsMalformedOrHostlessURLs(_ raw: String) {
        #expect(HTMLURLNormalizer.normalize(raw) == nil)
    }
}
