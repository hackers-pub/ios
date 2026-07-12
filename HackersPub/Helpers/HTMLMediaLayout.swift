import CoreGraphics

enum HTMLMediaLayout {
    static let fallbackHeight: CGFloat = 300
    static let maximumHeight: CGFloat = 500

    /// Uses the tallest valid item to keep a paged carousel from changing height
    /// while the user moves between landscape and portrait media.
    static func carouselHeight(containerWidth: CGFloat, media: [MediaItem]) -> CGFloat {
        guard containerWidth > 0 else {
            return fallbackHeight
        }

        let aspectRatios = media.compactMap { item -> CGFloat? in
            guard let width = item.width,
                  let height = item.height,
                  width > 0,
                  height > 0
            else {
                return nil
            }

            return CGFloat(height) / CGFloat(width)
        }

        guard let tallestAspectRatio = aspectRatios.max() else {
            return fallbackHeight
        }

        return min(containerWidth * tallestAspectRatio, maximumHeight)
    }

    static func downsamplingSize(
        containerWidth: CGFloat,
        carouselHeight: CGFloat,
        displayScale: CGFloat
    ) -> CGSize {
        let scale = max(displayScale, 1)
        return CGSize(
            width: max(containerWidth, 1) * scale,
            height: max(carouselHeight, 1) * scale
        )
    }
}

enum HTMLMediaPager {
    static func initialIndex(for media: MediaItem, in allMedia: [MediaItem]) -> Int {
        allMedia.firstIndex(where: { $0.id == media.id }) ?? 0
    }

    static func currentMedia(
        fallback: MediaItem,
        allMedia: [MediaItem],
        index: Int
    ) -> MediaItem {
        guard allMedia.indices.contains(index) else {
            return fallback
        }

        return allMedia[index]
    }
}
