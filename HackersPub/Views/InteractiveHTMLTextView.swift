import SwiftUI
import UIKit
import SafariServices

struct InteractiveHTMLTextView: UIViewRepresentable {
    private enum CommitTarget {
        case post(String)
        case link(URL)
    }

    let html: String
    @Binding var height: CGFloat
    let font: Font
    let color: Color
    var onTap: (() -> Void)?
    var authManager: AuthManager?
    var navigationCoordinator: NavigationCoordinator?
    var externalURLRouter: ExternalURLRouter?
    var sneakPeekPostId: String?
    var sneakPeekShareURL: URL?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ObservedObject private var fontSettings = FontSettingsManager.shared

    init(
        html: String,
        height: Binding<CGFloat>,
        font: Font = .body,
        color: Color = .primary,
        onTap: (() -> Void)? = nil,
        authManager: AuthManager? = nil,
        navigationCoordinator: NavigationCoordinator? = nil,
        externalURLRouter: ExternalURLRouter? = nil,
        sneakPeekPostId: String? = nil,
        sneakPeekShareURL: URL? = nil
    ) {
        self.html = html
        _height = height
        self.font = font
        self.color = color
        self.onTap = onTap
        self.authManager = authManager
        self.navigationCoordinator = navigationCoordinator
        self.externalURLRouter = externalURLRouter
        self.sneakPeekPostId = sneakPeekPostId
        self.sneakPeekShareURL = sneakPeekShareURL
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = SelfSizingTextView()
        textView.backgroundColor = .clear
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.showsVerticalScrollIndicator = false
        textView.showsHorizontalScrollIndicator = false
        textView.setContentOffset(.zero, animated: false)
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.textDragInteraction?.isEnabled = false
        textView.adjustsFontForContentSizeCategory = true
        textView.delegate = context.coordinator
        textView.linkTextAttributes = [
            .foregroundColor: HTMLTextRenderer.richLinkColor,
            .underlineStyle: 0,
        ]

        let tapRecognizer = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        tapRecognizer.cancelsTouchesInView = false
        tapRecognizer.delegate = context.coordinator
        textView.addGestureRecognizer(tapRecognizer)
        textView.addInteraction(UIContextMenuInteraction(delegate: context.coordinator))
        context.coordinator.textView = textView
        textView.onHeightChange = { [weak coordinator = context.coordinator] measuredHeight in
            coordinator?.updateMeasuredHeight(measuredHeight)
        }
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.parent = self
        textView.setContentOffset(.zero, animated: false)
        if let selfSizingTextView = textView as? SelfSizingTextView {
            selfSizingTextView.onHeightChange = { [weak coordinator = context.coordinator] measuredHeight in
                coordinator?.updateMeasuredHeight(measuredHeight)
            }
        }

        let cacheKey = HTMLTextRenderer.renderConfigurationKey(
            html: html,
            font: font,
            fontSettings: fontSettings,
            dynamicTypeSize: dynamicTypeSize,
            color: color
        )
        let textStyle = HTMLTextRenderer.textStyle(for: font)
        let weight = HTMLTextRenderer.defaultWeight(for: textStyle)
        let uiFont = fontSettings.uiFont(for: textStyle, weight: weight)
        let uiColor = UIColor(color)

        context.coordinator.render(
            cacheKey: cacheKey,
            html: html,
            uiFont: uiFont,
            uiColor: uiColor
        )
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: UITextView,
        context _: Context
    ) -> CGSize? {
        let targetWidth = max(proposal.width ?? uiView.bounds.width, 1)
        let size = uiView.sizeThatFits(
            CGSize(width: targetWidth, height: CGFloat.greatestFiniteMagnitude)
        )
        return CGSize(width: targetWidth, height: size.height)
    }

    final class Coordinator: NSObject, UITextViewDelegate, UIGestureRecognizerDelegate, UIContextMenuInteractionDelegate {
        var parent: InteractiveHTMLTextView
        weak var textView: SelfSizingTextView?
        private var renderTask: Task<Void, Never>?
        private var lastCacheKey: String?
        private var pendingCommitTarget: CommitTarget?

        init(parent: InteractiveHTMLTextView) {
            self.parent = parent
        }

        deinit {
            renderTask?.cancel()
        }

        func render(
            cacheKey: String,
            html: String,
            uiFont: UIFont,
            uiColor: UIColor
        ) {
            guard cacheKey != lastCacheKey else { return }
            lastCacheKey = cacheKey
            renderTask?.cancel()

            renderTask = Task { [weak self] in
                guard let self else { return }
                do {
                    let attributed = try await HTMLTextRenderer.attributedString(
                        cacheKey: cacheKey,
                        html: html,
                        uiFont: uiFont,
                        uiColor: uiColor
                    )
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        self.textView?.attributedText = attributed
                        self.textView?.setContentOffset(.zero, animated: false)
                        self.textView?.invalidateIntrinsicContentSize()
                        self.textView?.setNeedsLayout()
                        self.textView?.layoutIfNeeded()
                        self.textView?.reportHeightIfNeeded()
                    }
                } catch {
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        self.textView?.text = html
                        self.textView?.font = uiFont
                        self.textView?.textColor = uiColor
                        self.textView?.setContentOffset(.zero, animated: false)
                        self.textView?.invalidateIntrinsicContentSize()
                        self.textView?.setNeedsLayout()
                        self.textView?.layoutIfNeeded()
                        self.textView?.reportHeightIfNeeded()
                    }
                }
            }
        }

        func updateMeasuredHeight(_ measuredHeight: CGFloat) {
            guard measuredHeight > 0 else { return }
            if abs(parent.height - measuredHeight) > 0.5 {
                parent.height = measuredHeight
            }
        }

        @objc
        func handleTap(_ recognizer: UITapGestureRecognizer) {
            parent.onTap?()
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard gestureRecognizer is UITapGestureRecognizer,
                  let textView
            else {
                return true
            }
            return linkTarget(at: touch.location(in: textView)) == nil
        }

        func textView(
            _ textView: UITextView,
            shouldInteractWith url: URL,
            in characterRange: NSRange,
            interaction: UITextItemInteraction
        ) -> Bool {
            route(url: url)
            return false
        }

        func contextMenuInteraction(
            _: UIContextMenuInteraction,
            configurationForMenuAtLocation location: CGPoint
        ) -> UIContextMenuConfiguration? {
            if let linkURL = linkTarget(at: location) {
                pendingCommitTarget = .link(linkURL)
                return makeLinkContextMenuConfiguration(url: linkURL)
            }

            guard let postId = parent.sneakPeekPostId else {
                pendingCommitTarget = nil
                return nil
            }

            pendingCommitTarget = .post(postId)
            return makePostContextMenuConfiguration(postId: postId)
        }

        func contextMenuInteraction(
            _: UIContextMenuInteraction,
            willPerformPreviewActionForMenuWith _: UIContextMenuConfiguration,
            animator: UIContextMenuInteractionCommitAnimating
        ) {
            guard let target = pendingCommitTarget else { return }
            animator.addCompletion { [weak self] in
                self?.commit(target: target)
            }
        }

        private func linkTarget(at location: CGPoint) -> URL? {
            guard let textView else { return nil }

            let containerPoint = CGPoint(
                x: location.x - textView.textContainerInset.left,
                y: location.y - textView.textContainerInset.top
            )

            let layoutManager = textView.layoutManager
            let textContainer = textView.textContainer
            let characterIndex = layoutManager.characterIndex(
                for: containerPoint,
                in: textContainer,
                fractionOfDistanceBetweenInsertionPoints: nil
            )

            guard characterIndex < textView.textStorage.length else { return nil }

            var effectiveRange = NSRange(location: 0, length: 0)
            let value = textView.textStorage.attribute(
                .link,
                at: characterIndex,
                effectiveRange: &effectiveRange
            )

            guard value != nil else { return nil }

            let glyphRange = layoutManager.glyphRange(forCharacterRange: effectiveRange, actualCharacterRange: nil)
            let linkRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            guard linkRect.insetBy(dx: -8, dy: -8).contains(containerPoint) else { return nil }

            if let url = value as? URL {
                return url
            }
            if let raw = value as? String {
                return URL(string: raw)
            }
            return nil
        }

        private func makePostContextMenuConfiguration(postId: String) -> UIContextMenuConfiguration {
            UIContextMenuConfiguration(
                identifier: nil,
                previewProvider: { [weak self] in
                    self?.makePostPreviewController(postId: postId)
                },
                actionProvider: { [weak self] _ in
                    guard let self else { return UIMenu(children: []) }

                    var children: [UIMenuElement] = []
                    if let shareURL = self.parent.sneakPeekShareURL {
                        children.append(
                            UIAction(
                                title: NSLocalizedString("sneakpeek.action.sharePost", comment: "Share post"),
                                image: UIImage(systemName: "square.and.arrow.up")
                            ) { _ in
                                ShareSheetPresenter.present(items: [shareURL], from: self.textView)
                            }
                        )
                    }
                    return UIMenu(children: children)
                }
            )
        }

        private func makeLinkContextMenuConfiguration(url: URL) -> UIContextMenuConfiguration {
            UIContextMenuConfiguration(
                identifier: nil,
                previewProvider: {
                    SFSafariViewController(url: url)
                },
                actionProvider: { [weak self] _ in
                    guard let self else { return UIMenu(children: []) }
                    let openAction = UIAction(
                        title: NSLocalizedString("sneakpeek.action.openLink", comment: "Open link"),
                        image: UIImage(systemName: "safari")
                    ) { _ in
                        self.route(url: url)
                    }
                    let shareAction = UIAction(
                        title: NSLocalizedString("sneakpeek.action.shareLink", comment: "Share link"),
                        image: UIImage(systemName: "square.and.arrow.up")
                    ) { _ in
                        ShareSheetPresenter.present(items: [url], from: self.textView)
                    }
                    return UIMenu(children: [openAction, shareAction])
                }
            )
        }

        private func makePostPreviewController(postId: String) -> UIViewController {
            let preview = PostDetailView(postId: postId)
                .frame(width: previewWidth, height: previewHeight)
                .ignoresSafeArea()
                .environmentObject(FontSettingsManager.shared)

            var finalPreview = AnyView(preview)
            if let authManager = parent.authManager {
                finalPreview = AnyView(finalPreview.environment(authManager))
            }
            if let navigationCoordinator = parent.navigationCoordinator {
                finalPreview = AnyView(finalPreview.environment(navigationCoordinator))
            }
            if let externalURLRouter = parent.externalURLRouter {
                finalPreview = AnyView(finalPreview.environment(externalURLRouter))
            }

            let controller = UIHostingController(rootView: finalPreview)
            controller.view.backgroundColor = .systemBackground
            controller.view.insetsLayoutMarginsFromSafeArea = false
            controller.view.directionalLayoutMargins = .zero
            return controller
        }

        private var previewWidth: CGFloat {
            let screenWidth = UIScreen.main.bounds.width
            return min(380, max(280, screenWidth - 24))
        }

        private var previewHeight: CGFloat { 560 }

        private func commit(target: CommitTarget) {
            switch target {
            case .post(let postId):
                parent.navigationCoordinator?.navigateToPost(id: postId)
            case .link(let url):
                route(url: url)
            }
        }

        private func route(url: URL) {
            if url.host == "hackers.pub", url.path.hasPrefix("/@") {
                let handle = String(url.path.dropFirst(2))
                parent.navigationCoordinator?.navigateToProfile(handle: handle)
            } else {
                (parent.externalURLRouter ?? .shared).open(url)
            }
        }
    }
}

final class SelfSizingTextView: UITextView {
    private var lastKnownWidth: CGFloat = 0
    private var lastReportedHeight: CGFloat = 0
    var onHeightChange: ((CGFloat) -> Void)?

    private func measuredHeight(for width: CGFloat) -> CGFloat {
        guard width > 0 else { return 0 }

        let fittingSize = sizeThatFits(
            CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        ).height

        layoutManager.ensureLayout(for: textContainer)
        let usedRectHeight = layoutManager.usedRect(for: textContainer).height
            + textContainerInset.top
            + textContainerInset.bottom

        return ceil(max(fittingSize, usedRectHeight))
    }

    override var contentSize: CGSize {
        didSet {
            if oldValue != contentSize {
                invalidateIntrinsicContentSize()
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if contentOffset != .zero {
            setContentOffset(.zero, animated: false)
        }
        reportHeightIfNeeded()
        guard bounds.width > 0, bounds.width != lastKnownWidth else { return }
        lastKnownWidth = bounds.width
        invalidateIntrinsicContentSize()
        reportHeightIfNeeded()
    }

    override var intrinsicContentSize: CGSize {
        let targetWidth = bounds.width > 0 ? bounds.width : UIScreen.main.bounds.width
        return CGSize(width: UIView.noIntrinsicMetric, height: measuredHeight(for: targetWidth))
    }

    func reportHeightIfNeeded() {
        let targetWidth = bounds.width > 0 ? bounds.width : 0
        guard targetWidth > 0 else { return }
        let fittedHeight = measuredHeight(for: targetWidth)
        guard fittedHeight > 0, abs(fittedHeight - lastReportedHeight) > 0.5 else { return }
        lastReportedHeight = fittedHeight
        onHeightChange?(fittedHeight)
    }
}
