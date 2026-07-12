import SwiftUI
import UIKit

/// Detail-only rich text renderer. Feed previews retain their label-based
/// sneak-peek interaction, while this view exposes native text selection.
struct SelectableHTMLTextView: UIViewRepresentable {
    let html: String
    @Binding var height: CGFloat
    let font: Font
    let color: Color
    var authManager: AuthManager?
    var navigationCoordinator: NavigationCoordinator?
    var externalURLRouter: ExternalURLRouter?
    let attributedStringImporter: HTMLAttributedStringImporter

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ObservedObject private var fontSettings = FontSettingsManager.shared

    init(
        html: String,
        height: Binding<CGFloat>,
        font: Font = .body,
        color: Color = .primary,
        authManager: AuthManager? = nil,
        navigationCoordinator: NavigationCoordinator? = nil,
        externalURLRouter: ExternalURLRouter? = nil,
        attributedStringImporter: HTMLAttributedStringImporter = .production
    ) {
        self.html = html
        _height = height
        self.font = font
        self.color = color
        self.authManager = authManager
        self.navigationCoordinator = navigationCoordinator
        self.externalURLRouter = externalURLRouter
        self.attributedStringImporter = attributedStringImporter
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> SelfSizingSelectableHTMLTextView {
        let textView = SelfSizingSelectableHTMLTextView()
        HTMLTextInteractionPolicy.configure(textView, allowsSelection: true)
        textView.delegate = context.coordinator
        textView.onHeightChange = { [weak coordinator = context.coordinator] measuredHeight in
            coordinator?.updateMeasuredHeight(measuredHeight)
        }
        context.coordinator.textView = textView
        return textView
    }

    func updateUIView(_ textView: SelfSizingSelectableHTMLTextView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.textView = textView
        textView.onHeightChange = { [weak coordinator = context.coordinator] measuredHeight in
            coordinator?.updateMeasuredHeight(measuredHeight)
        }

        let cacheKey = HTMLTextRenderer.renderConfigurationKey(
            html: html,
            font: font,
            fontSettings: fontSettings,
            dynamicTypeSize: dynamicTypeSize,
            color: color
        )
        let textStyle = HTMLTextRenderer.textStyle(for: font)
        let uiFont = fontSettings.uiFont(
            for: textStyle,
            weight: HTMLTextRenderer.defaultWeight(for: textStyle)
        )
        context.coordinator.render(cacheKey: cacheKey, html: html, uiFont: uiFont, uiColor: UIColor(color))
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: SelfSizingSelectableHTMLTextView,
        context _: Context
    ) -> CGSize? {
        let width = max(proposal.width ?? uiView.bounds.width, 1)
        return CGSize(width: width, height: uiView.measuredHeight(for: width))
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: SelectableHTMLTextView
        weak var textView: SelfSizingSelectableHTMLTextView?
        private var renderTask: Task<Void, Never>?
        private var lastCacheKey: String?
        private var renderGeneration = 0

        init(parent: SelectableHTMLTextView) {
            self.parent = parent
        }

        deinit {
            renderTask?.cancel()
        }

        func render(cacheKey: String, html: String, uiFont: UIFont, uiColor: UIColor) {
            guard cacheKey != lastCacheKey else { return }
            lastCacheKey = cacheKey
            renderGeneration &+= 1
            renderTask?.cancel()
            let importer = parent.attributedStringImporter

            renderTask = Task { [weak self] in
                guard let self else { return }
                do {
                    let attributed = try await importer(
                        cacheKey: cacheKey,
                        html: html,
                        uiFont: uiFont,
                        uiColor: uiColor
                    )
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        self.apply(attributedText: attributed)
                    }
                } catch {
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        self.apply(attributedText: HTMLTextRenderer.visibleTextFallback(
                            html: html,
                            uiFont: uiFont,
                            uiColor: uiColor
                        ))
                    }
                }
            }
        }

        @MainActor
        private func apply(attributedText: NSAttributedString) {
            textView?.attributedText = attributedText
            textView?.invalidateIntrinsicContentSize()
            textView?.setNeedsLayout()
            textView?.layoutIfNeeded()
            textView?.reportHeightIfNeeded()
        }

        func updateMeasuredHeight(_ measuredHeight: CGFloat) {
            let scheduledGeneration = renderGeneration
            DispatchQueue.main.async { [weak self] in
                guard let self,
                      HTMLHeightUpdatePolicy.shouldApply(
                          currentGeneration: self.renderGeneration,
                          scheduledGeneration: scheduledGeneration,
                          currentHeight: Double(self.parent.height),
                          measuredHeight: Double(measuredHeight)
                      )
                else {
                    return
                }
                self.parent.height = measuredHeight
            }
        }

        func textView(
            _: UITextView,
            shouldInteractWith url: URL,
            in _: NSRange,
            interaction: UITextItemInteraction
        ) -> Bool {
            switch interaction {
            case .invokeDefaultAction:
                route(url: url)
                return false
            case .presentActions, .preview:
                return true
            @unknown default:
                return true
            }
        }

        private func route(url: URL) {
            guard let navigationCoordinator = parent.navigationCoordinator else {
                let router = parent.externalURLRouter ?? .shared
                if HackersPubURLRouter.isHackersPubWebURL(url) {
                    router.openInApp(url)
                } else {
                    router.open(url)
                }
                return
            }

            DeepLinkNavigator.open(
                url,
                authManager: parent.authManager ?? .shared,
                navigationCoordinator: navigationCoordinator,
                externalURLRouter: parent.externalURLRouter ?? .shared
            )
        }
    }
}

@MainActor
final class SelfSizingSelectableHTMLTextView: UITextView {
    private var lastKnownWidth: CGFloat = 0
    private var lastReportedHeight: CGFloat = 0
    var onHeightChange: ((CGFloat) -> Void)?

    override var attributedText: NSAttributedString! {
        didSet {
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    override var text: String! {
        didSet {
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    func measuredHeight(for width: CGFloat) -> CGFloat {
        guard width > 0 else { return 0 }
        let size = sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return ceil(size.height)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0, bounds.width != lastKnownWidth else { return }
        lastKnownWidth = bounds.width
        invalidateIntrinsicContentSize()
        reportHeightIfNeeded()
    }

    override var intrinsicContentSize: CGSize {
        let width = bounds.width > 0 ? bounds.width : UIScreen.main.bounds.width
        return CGSize(width: UIView.noIntrinsicMetric, height: measuredHeight(for: width))
    }

    func reportHeightIfNeeded() {
        guard bounds.width > 0 else { return }
        let measuredHeight = measuredHeight(for: bounds.width)
        guard measuredHeight > 0, abs(measuredHeight - lastReportedHeight) > 0.5 else { return }
        lastReportedHeight = measuredHeight
        onHeightChange?(measuredHeight)
    }
}
