import Apollo
import SafariServices
import SwiftUI
import UIKit

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
    var sneakPeekActorHandle: String?
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
        sneakPeekActorHandle: String? = nil,
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
        self.sneakPeekActorHandle = sneakPeekActorHandle
        self.sneakPeekShareURL = sneakPeekShareURL
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UILabel {
        let label = SelfSizingHTMLLabel()
        label.backgroundColor = .clear
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.adjustsFontForContentSizeCategory = true
        label.isUserInteractionEnabled = true

        let tapRecognizer = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        tapRecognizer.delegate = context.coordinator
        label.addGestureRecognizer(tapRecognizer)
        label.addInteraction(UIContextMenuInteraction(delegate: context.coordinator))

        context.coordinator.label = label
        label.onHeightChange = { [weak coordinator = context.coordinator] measuredHeight in
            coordinator?.updateMeasuredHeight(measuredHeight)
        }
        return label
    }

    func updateUIView(_ label: UILabel, context: Context) {
        context.coordinator.parent = self
        if let selfSizingLabel = label as? SelfSizingHTMLLabel {
            selfSizingLabel.onHeightChange = { [weak coordinator = context.coordinator] measuredHeight in
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
        uiView: UILabel,
        context _: Context
    ) -> CGSize? {
        let targetWidth = max(proposal.width ?? uiView.bounds.width, 1)
        let measuredHeight: CGFloat
        if let selfSizingLabel = uiView as? SelfSizingHTMLLabel {
            measuredHeight = selfSizingLabel.measuredHeight(for: targetWidth)
        } else {
            measuredHeight = uiView.sizeThatFits(
                CGSize(width: targetWidth, height: CGFloat.greatestFiniteMagnitude)
            ).height
        }
        return CGSize(width: targetWidth, height: measuredHeight)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate, UIContextMenuInteractionDelegate {
        var parent: InteractiveHTMLTextView
        weak var label: SelfSizingHTMLLabel?
        private var renderTask: Task<Void, Never>?
        private var lastCacheKey: String?
        private var pendingCommitTarget: CommitTarget?
        private var relationshipState: ActorRelationshipState?
        private var relationshipHandle: String?
        private var isLoadingRelationship = false
        private var isApplyingRelationshipAction = false

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
                        self.label?.attributedText = attributed
                        self.label?.invalidateIntrinsicContentSize()
                        self.label?.setNeedsLayout()
                        self.label?.layoutIfNeeded()
                        self.label?.reportHeightIfNeeded()
                    }
                } catch {
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        self.label?.text = html
                        self.label?.font = uiFont
                        self.label?.textColor = uiColor
                        self.label?.invalidateIntrinsicContentSize()
                        self.label?.setNeedsLayout()
                        self.label?.layoutIfNeeded()
                        self.label?.reportHeightIfNeeded()
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
            guard let label else { return }
            if let linkURL = linkTarget(at: recognizer.location(in: label)) {
                route(url: linkURL)
            } else {
                parent.onTap?()
            }
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard gestureRecognizer is UITapGestureRecognizer,
                  let label
            else {
                return true
            }
            return parent.onTap != nil || linkTarget(at: touch.location(in: label)) != nil
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
            guard let label,
                  let attributedText = label.attributedText,
                  attributedText.length > 0,
                  label.bounds.width > 0
            else { return nil }

            let textRect = label.textRect(
                forBounds: label.bounds,
                limitedToNumberOfLines: label.numberOfLines
            )
            guard textRect.insetBy(dx: -8, dy: -8).contains(location) else { return nil }

            let textStorage = NSTextStorage(attributedString: attributedText)
            let layoutManager = NSLayoutManager()
            let textContainer = NSTextContainer(size: textRect.size)
            textContainer.lineFragmentPadding = 0
            textContainer.maximumNumberOfLines = label.numberOfLines
            textContainer.lineBreakMode = label.lineBreakMode
            layoutManager.addTextContainer(textContainer)
            textStorage.addLayoutManager(layoutManager)
            layoutManager.ensureLayout(for: textContainer)

            let containerPoint = CGPoint(
                x: location.x - textRect.minX,
                y: location.y - textRect.minY
            )
            let characterIndex = layoutManager.characterIndex(
                for: containerPoint,
                in: textContainer,
                fractionOfDistanceBetweenInsertionPoints: nil
            )

            guard characterIndex < textStorage.length else { return nil }

            var effectiveRange = NSRange(location: 0, length: 0)
            let value = textStorage.attribute(
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
                    return self.makePostContextMenu()
                }
            )
        }

        private func makePostContextMenu() -> UIMenu {
            var children: [UIMenuElement] = []

            if let shareURL = parent.sneakPeekShareURL {
                children.append(
                    UIAction(
                        title: NSLocalizedString("sneakpeek.action.sharePost", comment: "Share post"),
                        image: UIImage(systemName: "square.and.arrow.up")
                    ) { [weak self] _ in
                        self?.presentShareSheet(items: [shareURL])
                    }
                )
            }

            if let userMenu = makeUserActionMenu() {
                children.append(userMenu)
            }

            return UIMenu(children: children)
        }

        private func makeUserActionMenu() -> UIMenu? {
            guard let handle = parent.sneakPeekActorHandle else { return nil }

            var userChildren: [UIMenuElement] = []

            if parent.authManager?.isAuthenticated == true {
                userChildren.append(
                    UIDeferredMenuElement { [weak self] completion in
                        guard let self else {
                            completion([])
                            return
                        }
                        Task {
                            _ = await self.loadRelationshipIfNeeded()
                            let elements = await MainActor.run {
                                self.relationshipActionElements()
                            }
                            completion(elements)
                        }
                    }
                )
            }

            if let profileURL = actorProfileURL(handle: handle) {
                userChildren.append(
                    UIAction(
                        title: NSLocalizedString("sneakpeek.action.shareProfileLink", comment: "Share profile link"),
                        image: UIImage(systemName: "link")
                    ) { [weak self] _ in
                        self?.presentShareSheet(items: [profileURL])
                    }
                )
            }

            guard !userChildren.isEmpty else { return nil }

            return UIMenu(
                title: NSLocalizedString("sneakpeek.menu.user", comment: "User menu"),
                image: UIImage(systemName: "person.crop.circle"),
                children: userChildren
            )
        }

        private func relationshipActionElements() -> [UIMenuElement] {
            guard let relationshipState, !relationshipState.isViewer else {
                return []
            }

            var followAttributes: UIMenuElement.Attributes = []
            if isApplyingRelationshipAction {
                followAttributes.insert(.disabled)
            }

            let followAction = UIAction(
                title: relationshipState.viewerFollows
                    ? NSLocalizedString("sneakpeek.action.unfollow", comment: "Unfollow action")
                    : NSLocalizedString("sneakpeek.action.follow", comment: "Follow action"),
                image: UIImage(systemName: relationshipState.viewerFollows ? "person.badge.minus" : "person.badge.plus"),
                attributes: followAttributes
            ) { [weak self] _ in
                self?.performRelationshipAction(relationshipState.viewerFollows ? .unfollow : .follow)
            }

            var blockAttributes: UIMenuElement.Attributes = []
            if isApplyingRelationshipAction {
                blockAttributes.insert(.disabled)
            }
            if !relationshipState.viewerBlocks {
                blockAttributes.insert(.destructive)
            }

            let blockAction = UIAction(
                title: relationshipState.viewerBlocks
                    ? NSLocalizedString("sneakpeek.action.unblock", comment: "Unblock action")
                    : NSLocalizedString("sneakpeek.action.block", comment: "Block action"),
                image: UIImage(systemName: relationshipState.viewerBlocks ? "nosign" : "hand.raised"),
                attributes: blockAttributes
            ) { [weak self] _ in
                self?.performRelationshipAction(relationshipState.viewerBlocks ? .unblock : .block)
            }

            return [followAction, blockAction]
        }

        private func performRelationshipAction(_ action: ActorRelationshipAction) {
            guard !isApplyingRelationshipAction else { return }
            guard let relationshipState else {
                Task {
                    _ = await loadRelationshipIfNeeded(forceNetwork: true)
                }
                return
            }

            isApplyingRelationshipAction = true
            Task {
                defer { isApplyingRelationshipAction = false }
                do {
                    try await ActorRelationshipService.perform(action: action, actorId: relationshipState.actorId)
                    if let handle = parent.sneakPeekActorHandle {
                        self.relationshipState = try await ActorRelationshipService.fetch(handle: handle, cachePolicy: .networkOnly)
                        self.relationshipHandle = handle
                    }
                } catch {
                    presentErrorAlert(message: error.localizedDescription)
                }
            }
        }

        @discardableResult
        private func loadRelationshipIfNeeded(forceNetwork: Bool = false) async -> ActorRelationshipState? {
            guard parent.authManager?.isAuthenticated == true,
                  let handle = parent.sneakPeekActorHandle
            else {
                relationshipState = nil
                relationshipHandle = nil
                return nil
            }

            if isLoadingRelationship {
                return relationshipState
            }

            if !forceNetwork, relationshipHandle == handle, let relationshipState {
                return relationshipState
            }

            isLoadingRelationship = true
            defer { isLoadingRelationship = false }
            do {
                let fetchedRelationship = try await ActorRelationshipService.fetch(
                    handle: handle,
                    cachePolicy: forceNetwork ? .networkOnly : .networkFirst
                )
                relationshipState = fetchedRelationship
                relationshipHandle = handle
                return fetchedRelationship
            } catch {
                relationshipState = nil
                relationshipHandle = nil
                return nil
            }
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
                        self.presentShareSheet(items: [url])
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

        private func presentShareSheet(items: [Any]) {
            ShareSheetPresenter.present(items: items, from: label)
        }

        private func presentErrorAlert(message: String) {
            guard let presenter = topViewController() else { return }

            let alert = UIAlertController(
                title: NSLocalizedString("actorRelation.error.title", comment: "Actor relation action error title"),
                message: message,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: NSLocalizedString("compose.error.ok", comment: "OK button"), style: .default))
            presenter.present(alert, animated: true)
        }

        private func topViewController(startingAt root: UIViewController? = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController) -> UIViewController?
        {
            guard let root else { return nil }

            if let presented = root.presentedViewController {
                return topViewController(startingAt: presented)
            }

            if let navigationController = root as? UINavigationController {
                return topViewController(startingAt: navigationController.visibleViewController)
            }

            if let tabBarController = root as? UITabBarController {
                return topViewController(startingAt: tabBarController.selectedViewController)
            }

            return root
        }
    }
}

final class SelfSizingHTMLLabel: UILabel {
    private var lastKnownWidth: CGFloat = 0
    private var lastReportedHeight: CGFloat = 0
    var onHeightChange: ((CGFloat) -> Void)?

    override var attributedText: NSAttributedString? {
        didSet {
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    override var text: String? {
        didSet {
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    override var font: UIFont! {
        didSet {
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    func measuredHeight(for width: CGFloat) -> CGFloat {
        guard width > 0 else { return 0 }
        preferredMaxLayoutWidth = width

        let fittingHeight = sizeThatFits(
            CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        ).height

        let textKitHeight = measuredTextKitHeight(for: width)
        let boundingHeight = attributedText?.boundingRect(
            with: CGSize(width: width, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).height ?? 0

        return ceil(max(fittingHeight, textKitHeight, boundingHeight)) + 4
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0, bounds.width != lastKnownWidth else { return }
        lastKnownWidth = bounds.width
        preferredMaxLayoutWidth = bounds.width
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

    private func measuredTextKitHeight(for width: CGFloat) -> CGFloat {
        guard let attributedText, attributedText.length > 0 else { return 0 }

        let textStorage = NSTextStorage(attributedString: attributedText)
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: CGSize(width: width, height: CGFloat.greatestFiniteMagnitude))
        textContainer.lineFragmentPadding = 0
        textContainer.maximumNumberOfLines = numberOfLines
        textContainer.lineBreakMode = lineBreakMode
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        layoutManager.ensureLayout(for: textContainer)
        return layoutManager.usedRect(for: textContainer).height
    }
}
