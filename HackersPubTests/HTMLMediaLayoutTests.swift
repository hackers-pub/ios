import CoreGraphics
@testable import HackersPub
import Testing

struct HTMLMediaLayoutTests {
    @Test
    func carouselUsesActualContainerWidthAndTallestValidAspectRatio() {
        let landscape = MediaItem(
            url: "https://example.com/landscape.jpg",
            thumbnailUrl: nil,
            alt: nil,
            width: 800,
            height: 400
        )
        let portrait = MediaItem(
            url: "https://example.com/portrait.jpg",
            thumbnailUrl: nil,
            alt: nil,
            width: 400,
            height: 600
        )

        #expect(HTMLMediaLayout.carouselHeight(containerWidth: 320, media: [landscape]) == 160)
        // The stable height favors the tallest page so paging does not jump;
        // shorter media is letterboxed by scaledToFit.
        #expect(HTMLMediaLayout.carouselHeight(containerWidth: 320, media: [landscape, portrait]) == 480)
    }

    @Test
    func carouselFallsBackForInvalidDimensionsAndCapsVeryTallMedia() {
        let invalid = MediaItem(
            url: "https://example.com/invalid.jpg",
            thumbnailUrl: nil,
            alt: nil,
            width: 0,
            height: 400
        )
        let veryTall = MediaItem(
            url: "https://example.com/tall.jpg",
            thumbnailUrl: nil,
            alt: nil,
            width: 100,
            height: 2000
        )

        #expect(HTMLMediaLayout.carouselHeight(containerWidth: 320, media: [invalid]) == HTMLMediaLayout.fallbackHeight)
        #expect(HTMLMediaLayout.carouselHeight(containerWidth: 320, media: [veryTall]) == HTMLMediaLayout.maximumHeight)
    }

    @Test
    func downsamplingMatchesTheMeasuredRenderSizeAtDisplayScale() {
        let size = HTMLMediaLayout.downsamplingSize(
            containerWidth: 320,
            carouselHeight: 480,
            displayScale: 2
        )

        #expect(size == CGSize(width: 640, height: 960))
    }

    @Test
    func pagerFallsBackToThePresentedMediaWhenCollectionIsEmptyOrIndexIsInvalid() {
        let fallback = MediaItem(
            id: "fallback",
            url: "https://example.com/fallback.jpg",
            thumbnailUrl: nil,
            alt: nil,
            width: nil,
            height: nil
        )
        let other = MediaItem(
            id: "other",
            url: "https://example.com/other.jpg",
            thumbnailUrl: nil,
            alt: nil,
            width: nil,
            height: nil
        )

        #expect(HTMLMediaPager.currentMedia(fallback: fallback, allMedia: [], index: 0).id == "fallback")
        #expect(HTMLMediaPager.currentMedia(fallback: fallback, allMedia: [other], index: 8).id == "fallback")
        #expect(HTMLMediaPager.initialIndex(for: fallback, in: []) == 0)
    }
}
