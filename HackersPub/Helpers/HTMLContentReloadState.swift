import CoreGraphics

struct HTMLContentReloadState: Equatable {
    private(set) var renderedHTML: String?
    private(set) var measuredHeight: CGFloat = 0
    private(set) var isLoading = true

    mutating func beginRendering(html: String) {
        guard renderedHTML != html else { return }

        renderedHTML = html
        measuredHeight = 0
        isLoading = true
    }

    mutating func applyMeasuredHeight(_ height: CGFloat, for html: String) {
        guard renderedHTML == html, height > 0 else { return }

        measuredHeight = height
        isLoading = false
    }

    func height(for html: String) -> CGFloat {
        renderedHTML == html ? measuredHeight : 0
    }

    func isLoading(for html: String) -> Bool {
        renderedHTML != html || isLoading
    }
}
