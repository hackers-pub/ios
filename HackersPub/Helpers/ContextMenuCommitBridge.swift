import SwiftUI
import UIKit

struct ContextMenuContainer<Content: View>: UIViewControllerRepresentable {
    let content: Content
    let makeConfiguration: () -> UIContextMenuConfiguration?
    let onCommit: (() -> Void)?

    func makeUIViewController(context: Context) -> HostingController<Content> {
        HostingController(
            rootView: content,
            makeConfiguration: makeConfiguration,
            onCommit: onCommit
        )
    }

    func updateUIViewController(_ uiViewController: HostingController<Content>, context _: Context) {
        uiViewController.update(
            rootView: content,
            makeConfiguration: makeConfiguration,
            onCommit: onCommit
        )
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiViewController: HostingController<Content>,
        context _: Context
    ) -> CGSize? {
        uiViewController.preferredSize(for: proposal)
    }
}

final class HostingController<Content: View>: UIViewController, UIContextMenuInteractionDelegate {
    private let hostingController: UIHostingController<Content>
    private var makeConfiguration: () -> UIContextMenuConfiguration?
    private var onCommit: (() -> Void)?

    init(
        rootView: Content,
        makeConfiguration: @escaping () -> UIContextMenuConfiguration?,
        onCommit: (() -> Void)?
    ) {
        hostingController = UIHostingController(rootView: rootView)
        self.makeConfiguration = makeConfiguration
        self.onCommit = onCommit
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .clear
        view.clipsToBounds = true

        addChild(hostingController)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController.view.backgroundColor = .clear
        view.addSubview(hostingController.view)
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        hostingController.didMove(toParent: self)
        if #available(iOS 16.0, *) {
            hostingController.sizingOptions = [.intrinsicContentSize]
        }

        view.addInteraction(UIContextMenuInteraction(delegate: self))
    }

    func update(
        rootView: Content,
        makeConfiguration: @escaping () -> UIContextMenuConfiguration?,
        onCommit: (() -> Void)?
    ) {
        hostingController.rootView = rootView
        self.makeConfiguration = makeConfiguration
        self.onCommit = onCommit
    }

    func preferredSize(for proposal: ProposedViewSize) -> CGSize {
        let fallbackWidth = max(view.bounds.width, UIScreen.main.bounds.width)
        let targetSize = CGSize(
            width: max(proposal.width ?? fallbackWidth, 1),
            height: proposal.height ?? CGFloat.greatestFiniteMagnitude
        )
        return hostingController.sizeThatFits(in: targetSize)
    }

    func contextMenuInteraction(
        _: UIContextMenuInteraction,
        configurationForMenuAtLocation _: CGPoint
    ) -> UIContextMenuConfiguration? {
        makeConfiguration()
    }

    func contextMenuInteraction(
        _: UIContextMenuInteraction,
        willPerformPreviewActionForMenuWith _: UIContextMenuConfiguration,
        animator: UIContextMenuInteractionCommitAnimating
    ) {
        guard let onCommit else { return }
        animator.addCompletion {
            DispatchQueue.main.async {
                onCommit()
            }
        }
    }
}

extension View {
    func uiContextMenu(
        makeConfiguration: @escaping () -> UIContextMenuConfiguration?,
        onCommit: (() -> Void)? = nil
    ) -> some View {
        ContextMenuContainer(
            content: self,
            makeConfiguration: makeConfiguration,
            onCommit: onCommit
        )
    }
}
