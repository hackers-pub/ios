// swiftlint:disable file_length
@testable import HackersPub
import Testing
import UIKit

@MainActor
// swiftlint:disable:next type_body_length
struct ShareSheetPresenterTests {
    @Test func foregroundActiveKeyWindowUsesVisibleTopPresenterAndFallbackPopoverAnchor() async throws {
        let inactiveRoot = UIViewController()
        let activeRoot = UIViewController()
        activeRoot.loadViewIfNeeded()
        activeRoot.view.frame = CGRect(x: 0, y: 0, width: 320, height: 640)

        let activityFactory = FakeActivityFactory()
        let driver = FakePresentationDriver()
        let presenter = ShareSheetPresenter(
            sceneProvider: FakeSceneProvider(scenes: [
                FakeScene(
                    activationState: .background,
                    windows: [FakeWindow(isKeyWindow: true, rootViewController: inactiveRoot)]
                ),
                FakeScene(
                    activationState: .foregroundActive,
                    windows: [FakeWindow(isKeyWindow: true, rootViewController: activeRoot)]
                )
            ]),
            activityFactory: activityFactory,
            presentationDriver: driver
        )

        let task = makePresentationTask(presenter, url: "https://hackers.pub")
        await allowPresenterToAdvance()

        #expect(driver.lastPresenter === activeRoot)
        let activity = try #require(activityFactory.latest)
        let configuration = try #require(activity.popoverConfiguration)
        #expect(configuration.sourceView === activeRoot.view)
        #expect(configuration.sourceRect == CGRect(x: 160, y: 320, width: 0, height: 0))
        #expect(configuration.arrowDirections.isEmpty)

        activity.completeActivity()
        try expectSuccess(await task.value)
    }

    @Test func inactiveSceneAndMissingPresenterRemainPendingUntilAvailabilityEvents() async throws {
        let root = UIViewController()
        let window = MutableFakeWindow(isKeyWindow: true, rootViewController: nil)
        let scene = MutableFakeScene(activationState: .background, windows: [window])
        let sceneProvider = FakeSceneProvider(scenes: [scene])
        let eventObserver = FakePresentationEventObserver()
        let activityFactory = FakeActivityFactory()
        let driver = FakePresentationDriver()
        let presenter = ShareSheetPresenter(
            sceneProvider: sceneProvider,
            activityFactory: activityFactory,
            presentationDriver: driver,
            eventObserver: eventObserver
        )

        let task = makePresentationTask(presenter, url: "https://hackers.pub")
        await allowPresenterToAdvance()
        #expect(driver.presentedCount == 0)

        scene.activationState = .foregroundActive
        eventObserver.fire()
        await allowPresenterToAdvance()
        #expect(driver.presentedCount == 0)

        window.rootViewController = root
        eventObserver.fire()
        await allowPresenterToAdvance()
        #expect(driver.lastPresenter === root)

        activityFactory.latest?.completeActivity()
        try expectSuccess(await task.value)
    }

    @Test func presentedAlertAboveSelectedNavigationTabIsThePresentationTarget() async throws {
        let leaf = UIViewController()
        let navigationController = UINavigationController(rootViewController: leaf)
        let tabController = UITabBarController()
        tabController.setViewControllers([UIViewController(), navigationController], animated: false)
        tabController.selectedViewController = navigationController

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window.rootViewController = tabController
        window.makeKeyAndVisible()

        let alert = UIAlertController(title: "Failure", message: nil, preferredStyle: .alert)
        leaf.present(alert, animated: false)
        await Task.yield()

        let factory = FakeActivityFactory()
        let driver = FakePresentationDriver()
        let presenter = ShareSheetPresenter(
            sceneProvider: FakeSceneProvider(scenes: [
                FakeScene(
                    activationState: .foregroundActive,
                    windows: [FakeWindow(isKeyWindow: true, rootViewController: tabController)]
                )
            ]),
            activityFactory: factory,
            presentationDriver: driver
        )

        let task = makePresentationTask(presenter, url: "https://hackers.pub")
        await allowPresenterToAdvance()

        #expect(driver.lastPresenter === alert)
        factory.latest?.completeActivity()
        try expectSuccess(await task.value)
    }

    @Test func iPadPopoverUsesTheSuppliedViewAndItsLocalCenterRect() async throws {
        let root = UIViewController()
        root.loadViewIfNeeded()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 500, height: 700))
        window.rootViewController = root
        window.makeKeyAndVisible()
        let sourceView = UIView(frame: CGRect(x: 20, y: 30, width: 120, height: 80))
        root.view.addSubview(sourceView)

        let factory = FakeActivityFactory()
        let presenter = ShareSheetPresenter(
            sceneProvider: FakeSceneProvider(scenes: [
                FakeScene(
                    activationState: .foregroundActive,
                    windows: [
                        FakeWindow(
                            isKeyWindow: true,
                            rootViewController: root,
                            uiWindow: window
                        )
                    ]
                )
            ]),
            activityFactory: factory,
            presentationDriver: FakePresentationDriver()
        )

        let task = Task { @MainActor in
            try await presenter.present(items: [URL(string: "https://hackers.pub")!], from: sourceView)
        }
        await allowPresenterToAdvance()

        let activity = try #require(factory.latest)
        let configuration = try #require(activity.popoverConfiguration)
        #expect(configuration.sourceView === sourceView)
        #expect(configuration.sourceRect == CGRect(x: 60, y: 40, width: 0, height: 0))
        activity.completeActivity()
        try expectSuccess(await task.value)
    }

    @Test func failedPresentationIsReturnedToTheCallerForVisibleErrorHandling() async throws {
        let root = UIViewController()
        let client = ShareSheetPresenter(
            sceneProvider: FakeSceneProvider(scenes: [
                FakeScene(
                    activationState: .foregroundActive,
                    windows: [FakeWindow(isKeyWindow: true, rootViewController: root)]
                )
            ]),
            activityFactory: FakeActivityFactory(),
            presentationDriver: FakePresentationDriver(shouldFail: true)
        )
        let caller = ShareSheetPresentationCaller(presenter: client)

        let failure = try await caller.present(items: [#require(URL(string: "https://hackers.pub"))])

        #expect(failure == .presentationFailed)
        guard let message = failure?.userFacingMessage else {
            Issue.record("Expected a user-facing error message")
            return
        }
        #expect(!message.isEmpty)
    }

    @Test func twoDifferentRequestsPromoteInFIFOOrderAfterBothDismissalSignals() async throws {
        let root = UIViewController()
        let factory = FakeActivityFactory()
        let driver = FakePresentationDriver()
        let presenter = makeForegroundPresenter(root: root, factory: factory, driver: driver)

        let firstTask = makePresentationTask(presenter, url: "https://hackers.pub/one")
        await allowPresenterToAdvance()
        let secondTask = makePresentationTask(presenter, url: "https://hackers.pub/two")
        await allowPresenterToAdvance()
        #expect(driver.presentedCount == 1)

        let firstActivity = try #require(factory.latest)
        firstActivity.completeActivity()
        firstActivity.dismissPresentation()
        await allowPresenterToAdvance()

        try expectSuccess(await firstTask.value)
        #expect(driver.presentedCount == 2)

        let secondActivity = try #require(factory.latest)
        secondActivity.completeActivity()
        try expectSuccess(await secondTask.value)
        #expect(driver.presentedCount == 2)
    }

    @Test func duplicatePayloadsCoalesceIntoOnePresentationAndResolveEveryCaller() async throws {
        let root = UIViewController()
        let factory = FakeActivityFactory()
        let driver = FakePresentationDriver()
        let presenter = makeForegroundPresenter(root: root, factory: factory, driver: driver)

        let firstTask = makePresentationTask(presenter, url: "https://hackers.pub/same")
        let secondTask = makePresentationTask(presenter, url: "https://hackers.pub/same")
        await allowPresenterToAdvance()
        #expect(driver.presentedCount == 1)

        factory.latest?.completeActivity()

        try expectSuccess(await firstTask.value)
        try expectSuccess(await secondTask.value)
        #expect(driver.presentedCount == 1)
    }

    @Test func cancellingAQueuedCallerRemovesItAndResumesCancellationError() async {
        let root = UIViewController()
        let scene = MutableFakeScene(
            activationState: .background,
            windows: [FakeWindow(isKeyWindow: true, rootViewController: root)]
        )
        let events = FakePresentationEventObserver()
        let factory = FakeActivityFactory()
        let driver = FakePresentationDriver()
        let presenter = ShareSheetPresenter(
            sceneProvider: FakeSceneProvider(scenes: [scene]),
            activityFactory: factory,
            presentationDriver: driver,
            eventObserver: events
        )

        let task = makePresentationTask(presenter, url: "https://hackers.pub/cancelled")
        await allowPresenterToAdvance()
        task.cancel()
        await allowPresenterToAdvance()

        let cancelledResult = await task.result
        guard case let .failure(error as CancellationError) = cancelledResult else {
            Issue.record("Expected a queued request to resume with CancellationError")
            return
        }
        #expect(error is CancellationError)

        scene.activationState = .foregroundActive
        events.fire()
        await allowPresenterToAdvance()
        #expect(driver.presentedCount == 0)
    }

    @Test func cancellingTheActiveCallerDismissesItBeforeTheNextRequestPromotes() async throws {
        let root = UIViewController()
        let factory = FakeActivityFactory()
        let driver = FakePresentationDriver()
        let presenter = makeForegroundPresenter(root: root, factory: factory, driver: driver)

        let activeTask = makePresentationTask(presenter, url: "https://hackers.pub/active")
        await allowPresenterToAdvance()
        let queuedTask = makePresentationTask(presenter, url: "https://hackers.pub/queued")
        await allowPresenterToAdvance()

        let activeActivity = try #require(factory.latest)
        activeTask.cancel()
        await allowPresenterToAdvance()

        #expect(activeActivity.dismissed)
        let activeResult = await activeTask.result
        guard case let .failure(error as CancellationError) = activeResult else {
            Issue.record("Expected an active request to resume with CancellationError")
            return
        }
        #expect(error is CancellationError)
        #expect(driver.presentedCount == 1)

        activeActivity.dismissPresentation()
        await allowPresenterToAdvance()
        #expect(driver.presentedCount == 2)

        factory.latest?.completeActivity()
        try expectSuccess(await queuedTask.value)
    }

    @Test func boundedPendingQueueReturnsLocalizedTypedOverflowInsteadOfDroppingARequest() async throws {
        let root = UIViewController()
        let scene = MutableFakeScene(
            activationState: .background,
            windows: [FakeWindow(isKeyWindow: true, rootViewController: root)]
        )
        let presenter = ShareSheetPresenter(
            sceneProvider: FakeSceneProvider(scenes: [scene]),
            activityFactory: FakeActivityFactory(),
            presentationDriver: FakePresentationDriver(),
            eventObserver: FakePresentationEventObserver()
        )

        let pendingTasks = (0 ..< ShareSheetPresenter.pendingQueueCapacity).map { index in
            makePresentationTask(presenter, url: "https://hackers.pub/pending/\(index)")
        }
        await allowPresenterToAdvance()

        let overflow = try await presenter.present(items: [#require(URL(string: "https://hackers.pub/overflow"))])
        expectFailure(overflow, .queueFull)
        #expect(!(ShareSheetPresentationError.queueFull.userFacingMessage).isEmpty)

        pendingTasks.forEach { $0.cancel() }
        await allowPresenterToAdvance()
        for task in pendingTasks {
            let result = await task.result
            guard case let .failure(error as CancellationError) = result else {
                Issue.record("Expected every cancelled pending request to finish")
                continue
            }
            #expect(error is CancellationError)
        }
    }
}

@MainActor
private func makeForegroundPresenter(
    root: UIViewController,
    factory: FakeActivityFactory,
    driver: FakePresentationDriver
) -> ShareSheetPresenter {
    ShareSheetPresenter(
        sceneProvider: FakeSceneProvider(scenes: [
            FakeScene(
                activationState: .foregroundActive,
                windows: [FakeWindow(isKeyWindow: true, rootViewController: root)]
            )
        ]),
        activityFactory: factory,
        presentationDriver: driver
    )
}

@MainActor
private func makePresentationTask(
    _ presenter: ShareSheetPresenter,
    url: String
) -> Task<ShareSheetPresentationResult, Error> {
    Task { @MainActor in
        try await presenter.present(items: [URL(string: url)!])
    }
}

private func allowPresenterToAdvance() async {
    await Task.yield()
    await Task.yield()
}

private func expectSuccess(_ result: ShareSheetPresentationResult) {
    guard case .success = result else {
        Issue.record("Expected share presentation to succeed, got \(result)")
        return
    }
}

private func expectFailure(
    _ result: ShareSheetPresentationResult,
    _ expectedError: ShareSheetPresentationError
) {
    guard case let .failure(error) = result else {
        Issue.record("Expected share presentation to fail with \(expectedError), got \(result)")
        return
    }
    #expect(error == expectedError)
}

@MainActor
private final class FakeSceneProvider: ShareSheetSceneProviding {
    let scenes: [any ShareSheetScene]

    init(scenes: [any ShareSheetScene]) {
        self.scenes = scenes
    }
}

@MainActor
private struct FakeScene: ShareSheetScene {
    let activationState: UIScene.ActivationState
    let windows: [any ShareSheetWindow]
}

@MainActor
private final class MutableFakeScene: ShareSheetScene {
    var activationState: UIScene.ActivationState
    let windows: [any ShareSheetWindow]

    init(activationState: UIScene.ActivationState, windows: [any ShareSheetWindow]) {
        self.activationState = activationState
        self.windows = windows
    }
}

@MainActor
private struct FakeWindow: ShareSheetWindow {
    let isKeyWindow: Bool
    let rootViewController: UIViewController?
    let isVisible: Bool
    let uiWindow: UIWindow?

    init(
        isKeyWindow: Bool,
        rootViewController: UIViewController?,
        isVisible: Bool = true,
        uiWindow: UIWindow? = nil
    ) {
        self.isKeyWindow = isKeyWindow
        self.rootViewController = rootViewController
        self.isVisible = isVisible
        self.uiWindow = uiWindow
    }
}

@MainActor
private final class MutableFakeWindow: ShareSheetWindow {
    var isKeyWindow: Bool
    var rootViewController: UIViewController?
    var isVisible: Bool
    var uiWindow: UIWindow?

    init(
        isKeyWindow: Bool,
        rootViewController: UIViewController?,
        isVisible: Bool = true,
        uiWindow: UIWindow? = nil
    ) {
        self.isKeyWindow = isKeyWindow
        self.rootViewController = rootViewController
        self.isVisible = isVisible
        self.uiWindow = uiWindow
    }
}

@MainActor
private final class FakePresentationEventObserver: ShareSheetPresentationEventObserving {
    private var handler: (@MainActor @Sendable () -> Void)?

    func beginObserving(_ handler: @escaping @MainActor @Sendable () -> Void) {
        self.handler = handler
    }

    func fire() {
        handler?()
    }
}

@MainActor
private final class FakeActivityFactory: ShareSheetActivityFactory {
    private(set) var activities: [FakeActivityController] = []

    var latest: FakeActivityController? {
        activities.last
    }

    func makeActivityController(items _: [Any]) -> any ShareSheetActivityController {
        let activity = FakeActivityController()
        activities.append(activity)
        return activity
    }
}

@MainActor
private final class FakeActivityController: ShareSheetActivityController {
    struct PopoverConfiguration {
        let sourceView: UIView
        let sourceRect: CGRect
        let arrowDirections: UIPopoverArrowDirection
    }

    let viewController = UIViewController()
    private(set) var popoverConfiguration: PopoverConfiguration?
    private var completion: (@MainActor @Sendable () -> Void)?
    private var dismissal: (@MainActor @Sendable () -> Void)?
    private var dismissCompletion: (@MainActor @Sendable () -> Void)?
    private(set) var dismissed = false

    func configurePopover(
        sourceView: UIView,
        sourceRect: CGRect,
        arrowDirections: UIPopoverArrowDirection
    ) {
        popoverConfiguration = PopoverConfiguration(
            sourceView: sourceView,
            sourceRect: sourceRect,
            arrowDirections: arrowDirections
        )
    }

    func setCompletionHandler(_ completion: @escaping @MainActor @Sendable () -> Void) {
        self.completion = completion
    }

    func setDismissalHandler(_ dismissal: @escaping @MainActor @Sendable () -> Void) {
        self.dismissal = dismissal
    }

    func activateDismissalObservation() {}

    func dismiss(
        animated _: Bool,
        completion: @escaping @MainActor @Sendable () -> Void
    ) {
        dismissed = true
        dismissCompletion = completion
    }

    func completeActivity() {
        completion?()
    }

    func dismissPresentation() {
        dismissal?()
        dismissCompletion?()
        dismissCompletion = nil
    }
}

@MainActor
private final class FakePresentationDriver: ShareSheetPresentationDriving {
    let shouldFail: Bool
    private(set) var lastPresenter: UIViewController?
    private(set) var presentedCount = 0

    init(shouldFail: Bool = false) {
        self.shouldFail = shouldFail
    }

    func present(
        _: any ShareSheetActivityController,
        from presenter: UIViewController
    ) throws {
        if shouldFail {
            throw PresentationFailure.rejected
        }
        lastPresenter = presenter
        presentedCount += 1
    }

    private enum PresentationFailure: Error {
        case rejected
    }
}
