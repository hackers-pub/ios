import CoreGraphics
import Foundation

enum HTMLContentRendererKind: Equatable {
    case richWebView
    case interactiveText
    case staticText
}

struct HTMLContentMediaRenderPlan: Identifiable {
    let item: MediaItem
    let sourceURL: URL?
    let downsamplingSize: CGSize
    let cancelsOnDisappear: Bool

    var id: String {
        item.id
    }
}

struct HTMLContentRenderPlan {
    struct Input {
        let html: String
        let media: [MediaItem]
        let renderMode: HTMLContentRenderMode
        let renderingContext: HTMLContentRenderingContext
        let hasTapHandler: Bool
        let sneakPeekPostId: String?
        let sneakPeekShareURL: URL?
        let mediaContainerWidth: CGFloat
        let displayScale: CGFloat
    }

    let rendererKind: HTMLContentRendererKind
    let allowsTextSelection: Bool
    let contentIdentity: String
    let carouselHeight: CGFloat
    let media: [HTMLContentMediaRenderPlan]

    @MainActor
    static func make(_ input: Input) -> Self {
        let rendererKind = rendererKind(for: input)
        let carouselHeight = HTMLMediaLayout.carouselHeight(
            containerWidth: input.mediaContainerWidth,
            media: input.media
        )
        let downsamplingSize = HTMLMediaLayout.downsamplingSize(
            containerWidth: input.mediaContainerWidth,
            carouselHeight: carouselHeight,
            displayScale: input.displayScale
        )

        return Self(
            rendererKind: rendererKind,
            allowsTextSelection: rendererKind == .interactiveText &&
                HTMLTextInteractionPolicy.allowsSelection(in: input.renderingContext),
            contentIdentity: input.sneakPeekPostId ?? input.html,
            carouselHeight: carouselHeight,
            media: input.media.map { item in
                HTMLContentMediaRenderPlan(
                    item: item,
                    sourceURL: item.thumbnailUrl.flatMap(URL.init(string:)) ?? URL(string: item.url),
                    downsamplingSize: downsamplingSize,
                    cancelsOnDisappear: true
                )
            }
        )
    }

    private static func rendererKind(for input: Input) -> HTMLContentRendererKind {
        switch input.renderingContext {
        case .feedPreview, .embeddedPreview:
            let hasInteractiveBehavior = input.hasTapHandler ||
                input.sneakPeekPostId != nil ||
                input.sneakPeekShareURL != nil ||
                containsAnchorHTML(input.html)
            return hasInteractiveBehavior ? .interactiveText : .staticText
        case .profileBio:
            return .interactiveText
        case .detail, .document:
            return input.renderMode == .richWebView ? .richWebView : .interactiveText
        }
    }

    private static func containsAnchorHTML(_ html: String) -> Bool {
        let normalized = html.lowercased()
        return normalized.contains("<a ") ||
            normalized.contains("<a\n") ||
            normalized.contains("href=")
    }
}
