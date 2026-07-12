import UIKit

// swiftlint:disable file_length

@MainActor
protocol ShareSheetSceneProviding {
    var scenes: [any ShareSheetScene] { get }
}

@MainActor
protocol ShareSheetScene {
    var activationState: UIScene.ActivationState { get }
    var windows: [any ShareSheetWindow] { get }
}

@MainActor
protocol ShareSheetWindow {
    var isKeyWindow: Bool { get }
    var isVisible: Bool { get }
    var rootViewController: UIViewController? { get }
    var uiWindow: UIWindow? { get }
}

@MainActor
protocol ShareSheetActivityController: AnyObject {
    var viewController: UIViewController { get }

    func configurePopover(
        sourceView: UIView,
        sourceRect: CGRect,
        arrowDirections: UIPopoverArrowDirection
    )
    func setCompletionHandler(_ completion: @escaping @MainActor @Sendable () -> Void)
    func setDismissalHandler(_ dismissal: @escaping @MainActor @Sendable () -> Void)
    func activateDismissalObservation()
    func dismiss(
        animated: Bool,
        completion: @escaping @MainActor @Sendable () -> Void
    )
}

@MainActor
protocol ShareSheetActivityFactory {
    func makeActivityController(items: [Any]) -> any ShareSheetActivityController
}

@MainActor
protocol ShareSheetPresentationDriving {
    func present(
        _ activityController: any ShareSheetActivityController,
        from presenter: UIViewController
    ) throws
}

@MainActor
protocol ShareSheetPresentationEventObserving: AnyObject {
    func beginObserving(_ handler: @escaping @MainActor @Sendable () -> Void)
}

@MainActor
protocol ShareSheetPresenting {
    func present(items: [Any], from view: UIView?) async throws -> ShareSheetPresentationResult
}

enum ShareSheetPresentationError: Error, Equatable {
    case emptyItems
    case noActiveScene
    case noPresentingWindow
    case noPresenter
    case sourceViewUnavailable
    case sourceViewIsNotInActiveScene
    case queueFull
    case presentationFailed

    var userFacingMessage: String {
        switch self {
        case .queueFull:
            NSLocalizedString(
                "share.error.queueFull",
                comment: "Share queue is full"
            )
        default:
            NSLocalizedString(
                "share.error.unavailable",
                comment: "Share sheet cannot be presented"
            )
        }
    }
}

typealias ShareSheetPresentationResult = Result<Void, ShareSheetPresentationError>

@MainActor
struct ShareSheetPresentationCaller {
    static let shared = ShareSheetPresentationCaller(presenter: ShareSheetPresenter.shared)

    private let presenter: any ShareSheetPresenting

    init(presenter: any ShareSheetPresenting) {
        self.presenter = presenter
    }

    func present(items: [Any], from view: UIView? = nil) async -> ShareSheetPresentationError? {
        do {
            switch try await presenter.present(items: items, from: view) {
            case .success:
                return nil
            case let .failure(error):
                return error
            }
        } catch is CancellationError {
            return nil
        } catch {
            return .presentationFailed
        }
    }
}

@MainActor
// The serialized request queue needs its lifecycle operations together.
// swiftlint:disable:next type_body_length
final class ShareSheetPresenter: ShareSheetPresenting {
    static let pendingQueueCapacity = 8

    static let shared = ShareSheetPresenter(
        sceneProvider: ApplicationShareSheetSceneProvider(),
        activityFactory: UIKitShareSheetActivityFactory(),
        presentationDriver: UIKitShareSheetPresentationDriver(),
        eventObserver: UIKitShareSheetPresentationEventObserver()
    )

    private let sceneProvider: any ShareSheetSceneProviding
    private let activityFactory: any ShareSheetActivityFactory
    private let presentationDriver: any ShareSheetPresentationDriving
    private let eventObserver: any ShareSheetPresentationEventObserving
    private var activeRequest: ShareSheetRequest?
    private var pendingRequests: [ShareSheetRequest] = []

    init(
        sceneProvider: any ShareSheetSceneProviding,
        activityFactory: any ShareSheetActivityFactory,
        presentationDriver: any ShareSheetPresentationDriving,
        eventObserver: any ShareSheetPresentationEventObserving
    ) {
        self.sceneProvider = sceneProvider
        self.activityFactory = activityFactory
        self.presentationDriver = presentationDriver
        self.eventObserver = eventObserver

        eventObserver.beginObserving { [weak self] in
            self?.advanceQueueIfPossible()
        }
    }

    convenience init(
        sceneProvider: any ShareSheetSceneProviding,
        activityFactory: any ShareSheetActivityFactory,
        presentationDriver: any ShareSheetPresentationDriving
    ) {
        self.init(
            sceneProvider: sceneProvider,
            activityFactory: activityFactory,
            presentationDriver: presentationDriver,
            eventObserver: NoopShareSheetPresentationEventObserver()
        )
    }

    func present(items: [Any], from view: UIView? = nil) async throws -> ShareSheetPresentationResult {
        guard !items.isEmpty else {
            return .failure(.emptyItems)
        }
        try Task.checkCancellation()

        let waiterID = UUID()
        let payloadIdentity = ShareSheetPayloadIdentity(items: items)

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard !Task.isCancelled else {
                    continuation.resume(throwing: CancellationError())
                    return
                }

                enqueue(
                    waiterID: waiterID,
                    continuation: continuation,
                    items: items,
                    sourceView: view,
                    payloadIdentity: payloadIdentity
                )
            }
        } onCancel: { [weak self] in
            Task { @MainActor [weak self] in
                self?.cancel(waiterID: waiterID)
            }
        }
    }

    private func enqueue(
        waiterID: UUID,
        continuation: CheckedContinuation<ShareSheetPresentationResult, Error>,
        items: [Any],
        sourceView: UIView?,
        payloadIdentity: ShareSheetPayloadIdentity?
    ) {
        // Equivalent, stable payloads coalesce while waiting or presenting. Values
        // without a stable identity deliberately stay as distinct FIFO requests.
        // A view-backed request only coalesces with the same anchor view.
        if let payloadIdentity {
            if let existingRequest = matchingRequest(for: payloadIdentity, sourceView: sourceView) {
                existingRequest.add(waiterID: waiterID, continuation: continuation)
                return
            }
        }

        guard pendingRequests.count < Self.pendingQueueCapacity else {
            continuation.resume(returning: .failure(.queueFull))
            return
        }

        let request = ShareSheetRequest(
            items: items,
            sourceView: sourceView,
            payloadIdentity: payloadIdentity
        )
        request.add(waiterID: waiterID, continuation: continuation)
        pendingRequests.append(request)
        advanceQueueIfPossible()
    }

    private func matchingRequest(
        for payloadIdentity: ShareSheetPayloadIdentity,
        sourceView: UIView?
    ) -> ShareSheetRequest? {
        if let activeRequest, !activeRequest.isCancellationDismissalRequested {
            if activeRequest.matches(payloadIdentity: payloadIdentity, sourceView: sourceView) {
                return activeRequest
            }
        }

        return pendingRequests.first {
            $0.matches(payloadIdentity: payloadIdentity, sourceView: sourceView)
        }
    }

    private func cancel(waiterID: UUID) {
        if let activeRequest, let continuation = activeRequest.remove(waiterID: waiterID) {
            continuation.resume(throwing: CancellationError())
            if activeRequest.hasNoWaiters {
                dismissActiveRequest(activeRequest)
            }
            return
        }

        guard let index = pendingRequests.firstIndex(where: { $0.contains(waiterID: waiterID) }) else {
            return
        }

        let request = pendingRequests[index]
        if let continuation = request.remove(waiterID: waiterID) {
            continuation.resume(throwing: CancellationError())
        }
        if request.hasNoWaiters {
            pendingRequests.remove(at: index)
        }
        advanceQueueIfPossible()
    }

    private func dismissActiveRequest(_ request: ShareSheetRequest) {
        guard activeRequest === request,
              !request.isCancellationDismissalRequested
        else {
            return
        }

        request.isCancellationDismissalRequested = true
        guard let activityController = request.activityController else {
            finishActiveRequest(request, with: .failure(.presentationFailed))
            return
        }

        activityController.dismiss(animated: true) { [weak self, weak request] in
            guard let self, let request else { return }
            self.finishActiveRequest(request, with: .success(()))
        }
    }

    private func advanceQueueIfPossible() {
        guard activeRequest == nil else { return }

        while let request = pendingRequests.first {
            guard !request.hasNoWaiters else {
                pendingRequests.removeFirst()
                continue
            }

            switch presentationTarget(
                for: request.sourceView,
                requiresSourceView: request.requiresSourceView
            ) {
            case let .success(target):
                pendingRequests.removeFirst()
                startPresentation(of: request, at: target)
                return
            case let .failure(error) where error.isAvailabilityIssue:
                return
            case let .failure(error):
                pendingRequests.removeFirst()
                finishRequest(request, with: .failure(error))
            }
        }
    }

    private func startPresentation(of request: ShareSheetRequest, at target: PresentationTarget) {
        let activityController = activityFactory.makeActivityController(items: request.items)
        request.activityController = activityController
        activeRequest = request

        let sourceRect = CGRect(
            x: target.sourceView.bounds.midX,
            y: target.sourceView.bounds.midY,
            width: 0,
            height: 0
        )
        activityController.configurePopover(
            sourceView: target.sourceView,
            sourceRect: sourceRect,
            arrowDirections: []
        )
        activityController.setCompletionHandler { [weak self, weak request] in
            guard let self, let request else { return }
            self.finishActiveRequest(request, with: .success(()))
        }
        activityController.setDismissalHandler { [weak self, weak request] in
            guard let self, let request else { return }
            self.finishActiveRequest(request, with: .success(()))
        }

        do {
            try presentationDriver.present(activityController, from: target.presenter)
            activityController.activateDismissalObservation()
        } catch {
            finishActiveRequest(request, with: .failure(.presentationFailed))
        }
    }

    private func finishActiveRequest(
        _ request: ShareSheetRequest,
        with result: ShareSheetPresentationResult
    ) {
        guard activeRequest === request else { return }

        activeRequest = nil
        request.activityController = nil
        finishRequest(request, with: result)
        advanceQueueIfPossible()
    }

    private func finishRequest(_ request: ShareSheetRequest, with result: ShareSheetPresentationResult) {
        for continuation in request.removeAllWaiters() {
            continuation.resume(returning: result)
        }
    }

    private func presentationTarget(
        for sourceView: UIView?,
        requiresSourceView: Bool
    ) -> Result<PresentationTarget, ShareSheetPresentationError> {
        let activeScenes = sceneProvider.scenes.filter { $0.activationState == .foregroundActive }
        guard !activeScenes.isEmpty else {
            return .failure(.noActiveScene)
        }

        let visibleWindows = activeScenes
            .flatMap(\.windows)
            .filter(\.isVisible)
        guard !visibleWindows.isEmpty else {
            return .failure(.noPresentingWindow)
        }

        let selectedWindow: any ShareSheetWindow
        let popoverSourceView: UIView

        if requiresSourceView, sourceView == nil {
            return .failure(.sourceViewUnavailable)
        }

        if let sourceView {
            guard let sourceWindow = sourceView.window else {
                return .failure(.sourceViewUnavailable)
            }
            guard let matchingWindow = visibleWindows.first(where: { $0.uiWindow === sourceWindow }) else {
                return .failure(.sourceViewIsNotInActiveScene)
            }
            selectedWindow = matchingWindow
            popoverSourceView = sourceView
        } else {
            guard let keyWindow = visibleWindows.first(where: \.isKeyWindow) else {
                return .failure(.noPresentingWindow)
            }
            selectedWindow = keyWindow
            guard let rootViewController = keyWindow.rootViewController else {
                return .failure(.noPresenter)
            }
            let presenter = topViewController(startingAt: rootViewController)
            return .success(
                PresentationTarget(
                    presenter: presenter,
                    sourceView: presenter.view
                )
            )
        }

        guard let rootViewController = selectedWindow.rootViewController else {
            return .failure(.noPresenter)
        }

        return .success(
            PresentationTarget(
                presenter: topViewController(startingAt: rootViewController),
                sourceView: popoverSourceView
            )
        )
    }

    private func topViewController(startingAt root: UIViewController) -> UIViewController {
        if let presented = root.presentedViewController, !presented.isBeingDismissed {
            return topViewController(startingAt: presented)
        }

        if let navigationController = root as? UINavigationController {
            if let visibleViewController = navigationController.visibleViewController {
                return topViewController(startingAt: visibleViewController)
            }
        }

        if let tabBarController = root as? UITabBarController {
            if let selectedViewController = tabBarController.selectedViewController {
                return topViewController(startingAt: selectedViewController)
            }
        }

        return root
    }
}

private extension ShareSheetPresentationError {
    var isAvailabilityIssue: Bool {
        switch self {
        case .noActiveScene, .noPresentingWindow, .noPresenter, .sourceViewIsNotInActiveScene:
            true
        case .emptyItems, .sourceViewUnavailable, .queueFull, .presentationFailed:
            false
        }
    }
}

@MainActor
private final class ShareSheetRequest {
    let items: [Any]
    weak var sourceView: UIView?
    let requiresSourceView: Bool
    let payloadIdentity: ShareSheetPayloadIdentity?
    var activityController: (any ShareSheetActivityController)?
    var isCancellationDismissalRequested = false

    private var waiters: [UUID: CheckedContinuation<ShareSheetPresentationResult, Error>] = [:]

    init(items: [Any], sourceView: UIView?, payloadIdentity: ShareSheetPayloadIdentity?) {
        self.items = items
        self.sourceView = sourceView
        requiresSourceView = sourceView != nil
        self.payloadIdentity = payloadIdentity
    }

    var hasNoWaiters: Bool {
        waiters.isEmpty
    }

    func add(
        waiterID: UUID,
        continuation: CheckedContinuation<ShareSheetPresentationResult, Error>
    ) {
        waiters[waiterID] = continuation
    }

    func contains(waiterID: UUID) -> Bool {
        waiters[waiterID] != nil
    }

    func matches(payloadIdentity: ShareSheetPayloadIdentity, sourceView: UIView?) -> Bool {
        guard self.payloadIdentity == payloadIdentity,
              requiresSourceView == (sourceView != nil)
        else {
            return false
        }

        switch (self.sourceView, sourceView) {
        case (nil, nil):
            return !requiresSourceView
        case let (storedSourceView?, candidateSourceView?):
            return storedSourceView === candidateSourceView
        default:
            return false
        }
    }

    func remove(waiterID: UUID) -> CheckedContinuation<ShareSheetPresentationResult, Error>? {
        waiters.removeValue(forKey: waiterID)
    }

    func removeAllWaiters() -> [CheckedContinuation<ShareSheetPresentationResult, Error>] {
        defer { waiters.removeAll() }
        return Array(waiters.values)
    }
}

private struct ShareSheetPayloadIdentity: Hashable {
    private enum Item: Hashable {
        case url(String)
        case text(String)
        case object(ObjectIdentifier)
    }

    private let items: [Item]

    init?(items: [Any]) {
        var identities: [Item] = []
        identities.reserveCapacity(items.count)

        for item in items {
            if let url = item as? URL {
                identities.append(.url(url.absoluteString))
            } else if let url = item as? NSURL, let absoluteString = url.absoluteString {
                identities.append(.url(absoluteString))
            } else if let text = item as? String {
                identities.append(.text(text))
            } else if let text = item as? NSString {
                identities.append(.text(text as String))
            } else if let object = item as? NSObject {
                identities.append(.object(ObjectIdentifier(object)))
            } else {
                return nil
            }
        }

        self.items = identities
    }
}

@MainActor
private struct PresentationTarget {
    let presenter: UIViewController
    let sourceView: UIView
}

@MainActor
private struct ApplicationShareSheetSceneProvider: ShareSheetSceneProviding {
    var scenes: [any ShareSheetScene] {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .map(UIKitShareSheetScene.init)
    }
}

@MainActor
private struct UIKitShareSheetScene: ShareSheetScene {
    let scene: UIWindowScene

    var activationState: UIScene.ActivationState {
        scene.activationState
    }

    var windows: [any ShareSheetWindow] {
        scene.windows.map(UIKitShareSheetWindow.init)
    }
}

@MainActor
private struct UIKitShareSheetWindow: ShareSheetWindow {
    let window: UIWindow

    var isKeyWindow: Bool {
        window.isKeyWindow
    }

    var isVisible: Bool {
        !window.isHidden && window.alpha > 0 && !window.bounds.isEmpty
    }

    var rootViewController: UIViewController? {
        window.rootViewController
    }

    var uiWindow: UIWindow? {
        window
    }
}

@MainActor
private final class UIKitShareSheetPresentationEventObserver: ShareSheetPresentationEventObserving {
    private var observationTokens: [NSObjectProtocol] = []

    func beginObserving(_ handler: @escaping @MainActor @Sendable () -> Void) {
        guard observationTokens.isEmpty else { return }

        let notificationCenter = NotificationCenter.default
        let notifications = [
            UIScene.didActivateNotification,
            UIWindow.didBecomeKeyNotification
        ]
        observationTokens = notifications.map { notification in
            notificationCenter.addObserver(
                forName: notification,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    handler()
                }
            }
        }
    }

    deinit {
        observationTokens.forEach(NotificationCenter.default.removeObserver)
    }
}

@MainActor
private final class NoopShareSheetPresentationEventObserver: ShareSheetPresentationEventObserving {
    func beginObserving(_: @escaping @MainActor @Sendable () -> Void) {}
}

@MainActor
private final class UIKitShareSheetActivityController: ShareSheetActivityController {
    private let activityViewController: UIActivityViewController
    private var dismissalObserver: ShareSheetDismissalObserver?

    init(items: [Any]) {
        activityViewController = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
    }

    var viewController: UIViewController {
        activityViewController
    }

    func configurePopover(
        sourceView: UIView,
        sourceRect: CGRect,
        arrowDirections: UIPopoverArrowDirection
    ) {
        guard let popover = activityViewController.popoverPresentationController else { return }
        popover.sourceView = sourceView
        popover.sourceRect = sourceRect
        popover.permittedArrowDirections = arrowDirections
    }

    func setCompletionHandler(_ completion: @escaping @MainActor @Sendable () -> Void) {
        activityViewController.completionWithItemsHandler = { _, _, _, _ in
            Task { @MainActor in
                completion()
            }
        }
    }

    func setDismissalHandler(_ dismissal: @escaping @MainActor @Sendable () -> Void) {
        dismissalObserver = ShareSheetDismissalObserver(dismissal: dismissal)
        activateDismissalObservation()
    }

    func activateDismissalObservation() {
        guard let dismissalObserver else { return }
        activityViewController.presentationController?.delegate = dismissalObserver
    }

    func dismiss(
        animated: Bool,
        completion: @escaping @MainActor @Sendable () -> Void
    ) {
        activityViewController.dismiss(animated: animated) {
            Task { @MainActor in
                completion()
            }
        }
    }
}

private final class ShareSheetDismissalObserver: NSObject, UIAdaptivePresentationControllerDelegate {
    private let dismissal: @MainActor @Sendable () -> Void

    init(dismissal: @escaping @MainActor @Sendable () -> Void) {
        self.dismissal = dismissal
    }

    func presentationControllerDidDismiss(_: UIPresentationController) {
        Task { @MainActor in
            dismissal()
        }
    }
}

@MainActor
private struct UIKitShareSheetActivityFactory: ShareSheetActivityFactory {
    func makeActivityController(items: [Any]) -> any ShareSheetActivityController {
        UIKitShareSheetActivityController(items: items)
    }
}

@MainActor
private struct UIKitShareSheetPresentationDriver: ShareSheetPresentationDriving {
    func present(
        _ activityController: any ShareSheetActivityController,
        from presenter: UIViewController
    ) throws {
        presenter.present(activityController.viewController, animated: true)
    }
}
